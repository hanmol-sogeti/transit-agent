/// E2E integration test – Azure OpenAI (ReseAgenten)
///
/// Kräver att .env finns i projektroten och innehåller giltiga
/// värden för AZURE_OPENAI_*.
///
/// Kör med:
///   flutter test test/integration/azure_openai_e2e_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:transit_agent/config/env_config.dart';
import 'package:transit_agent/services/azure_openai_service.dart';

void main() {
  AzureOpenAiService? sut;
  bool envLoaded = false;

  setUpAll(() async {
    try {
      await EnvConfig.load();
      sut = AzureOpenAiService();
      envLoaded = true;
    } on EnvLoadException catch (e) {
      // Tests will be skipped individually below.
      printOnFailure('Env-fil saknas: $e');
    }
  });

  tearDownAll(() {
    sut?.dispose();
  });

  group('Azure OpenAI – e2e', () {
    // ── Sanity check ─────────────────────────────────────────────────────────

    test('sanityCheck() svarar true', () async {
      if (!envLoaded) markTestSkipped('Env-fil saknas – hoppar över test.');
      final ok = await sut!.sanityCheck();
      expect(ok, isTrue, reason: 'LLM ska svara på ett enkelt hälsningsmeddelande.');
    });

    // ── Enkel textgenerering ──────────────────────────────────────────────────

    test('chatCompletion() returnerar icke-tomt innehåll på svenska', () async {
      if (!envLoaded) markTestSkipped('Env-fil saknas – hoppar över test.');
      final response = await sut!.chatCompletion(
        messages: [
          OpenAiMessage.system(
            'Du är en hjälpsam assistent. Svara alltid på svenska.',
          ),
          OpenAiMessage.user('Vad heter Sveriges huvudstad?'),
        ],
        maxTokens: 100,
      );

      expect(response.id, isNotEmpty);
      expect(response.content, isNotNull);
      expect(response.content, isNotEmpty);
      expect(response.content!.toLowerCase(), contains('stockholm'));
      expect(response.finishReason, equals('stop'));
      expect(response.promptTokens, greaterThan(0));
      expect(response.completionTokens, greaterThan(0));
    });

    test('chatCompletion() respekterar maxTokens-begränsning', () async {
      if (!envLoaded) markTestSkipped('Env-fil saknas – hoppar över test.');
      final response = await sut!.chatCompletion(
        messages: [
          OpenAiMessage.user('Skriv en berättelse om ett tåg. Fortsätt så länge du kan.'),
        ],
        maxTokens: 20,
      );

      // finish_reason should be 'length' when truncated, or 'stop' for short answers
      expect(
        ['stop', 'length'],
        contains(response.finishReason),
      );
      expect(response.completionTokens, lessThanOrEqualTo(25));
    });

    // ── Tool calling / function calling ──────────────────────────────────────

    test('chatCompletion() anropar rätt verktyg vid verktygsdefinition', () async {
      if (!envLoaded) markTestSkipped('Env-fil saknas – hoppar över test.');
      final tools = [
        OpenAiTool(
          name: 'search_stops',
          description: 'Sök efter hållplatser nära en plats.',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Platsen att söka hållplatser nära.',
              },
            },
            'required': ['query'],
          },
        ),
      ];

      final response = await sut!.chatCompletion(
        messages: [
          OpenAiMessage.system(
            'Du är en kollektivtrafikassistent. Använd alltid tillgängliga verktyg.',
          ),
          OpenAiMessage.user('Hitta hållplatser i närheten av Centralstationen i Stockholm.'),
        ],
        tools: tools,
        maxTokens: 256,
      );

      expect(response.hasToolCalls, isTrue,
          reason: 'LLM ska vilja anropa search_stops-verktyget.');

      final toolCall = response.toolCalls!.first;
      expect(toolCall.functionName, equals('search_stops'));
      expect(toolCall.arguments, contains('query'));
      expect(
        toolCall.arguments['query'].toString().toLowerCase(),
        anyOf(contains('central'), contains('stockholm')),
      );
    });

    test('chatCompletion() hanterar tool_result och svarar med text', () async {
      if (!envLoaded) markTestSkipped('Env-fil saknas – hoppar över test.');
      final tools = [
        OpenAiTool(
          name: 'get_departures',
          description: 'Hämtar avgångar från en hållplats.',
          parameters: {
            'type': 'object',
            'properties': {
              'stop_id': {'type': 'string'},
            },
            'required': ['stop_id'],
          },
        ),
      ];

      // Round 1: get tool call
      final round1 = await sut!.chatCompletion(
        messages: [
          OpenAiMessage.system('Du är en kollektivtrafikassistent. Svara på svenska.'),
          OpenAiMessage.user('Vilka bussar går från T-Centralen om 5 minuter?'),
        ],
        tools: tools,
        maxTokens: 256,
      );

      expect(round1.hasToolCalls, isTrue);
      final tc = round1.toolCalls!.first;

      // Round 2: feed back a mock tool result
      final round2 = await sut!.chatCompletion(
        messages: [
          OpenAiMessage.system('Du är en kollektivtrafikassistent. Svara på svenska.'),
          OpenAiMessage.user('Vilka bussar går från T-Centralen om 5 minuter?'),
          OpenAiMessage(
            role: 'assistant',
            content: round1.content,
            toolCalls: [
              {
                'id': tc.id,
                'type': 'function',
                'function': {
                  'name': tc.functionName,
                  'arguments': '{"stop_id":"740000001"}',
                },
              },
            ],
          ),
          OpenAiMessage.toolResult(
            tc.id,
            '{"departures":[{"line":"Buss 1","direction":"Universitetet","time":"14:05"},'
            '{"line":"Buss 6","direction":"Djurgården","time":"14:07"}]}',
          ),
        ],
        tools: tools,
        maxTokens: 300,
      );

      expect(round2.content, isNotNull);
      expect(round2.content, isNotEmpty);
      // Should mention buses or departures
      expect(
        round2.content!.toLowerCase(),
        anyOf(
          contains('buss'),
          contains('avgång'),
          contains('14:0'),
        ),
      );
    });

    // ── Felhantering ─────────────────────────────────────────────────────────

    test('OpenAiMessage.toJson() serialiseras korrekt', () {
      final msg = OpenAiMessage.user('Test');
      expect(msg.toJson(), equals({'role': 'user', 'content': 'Test'}));
    });

    test('OpenAiMessage – alla roller serialiseras', () {
      final system = OpenAiMessage.system('sys');
      expect(system.toJson()['role'], 'system');

      final assistant = OpenAiMessage.assistant('resp');
      expect(assistant.toJson()['role'], 'assistant');

      final tool = OpenAiMessage.toolResult('call_abc123', '{"ok":true}');
      expect(tool.toJson()['role'], 'tool');
      expect(tool.toJson()['tool_call_id'], 'call_abc123');
    });

    test('OpenAiResponse.fromJson() parsar svar korrekt', () {
      final json = {
        'id': 'chatcmpl-test123',
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'Hej!'},
            'finish_reason': 'stop',
          }
        ],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
      };
      final response = OpenAiResponse.fromJson(json);
      expect(response.id, 'chatcmpl-test123');
      expect(response.content, 'Hej!');
      expect(response.finishReason, 'stop');
      expect(response.promptTokens, 10);
      expect(response.completionTokens, 5);
      expect(response.hasToolCalls, isFalse);
    });

    test('OpenAiResponse.fromJson() parsar tool_calls korrekt', () {
      final json = {
        'id': 'chatcmpl-tool',
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': null,
              'tool_calls': [
                {
                  'id': 'call_xyz',
                  'type': 'function',
                  'function': {
                    'name': 'search_stops',
                    'arguments': '{"query":"Uppsala"}',
                  },
                }
              ],
            },
            'finish_reason': 'tool_calls',
          }
        ],
        'usage': {'prompt_tokens': 20, 'completion_tokens': 15},
      };
      final response = OpenAiResponse.fromJson(json);
      expect(response.hasToolCalls, isTrue);
      expect(response.toolCalls!.first.functionName, 'search_stops');
      expect(response.toolCalls!.first.arguments['query'], 'Uppsala');
    });
  });
}
