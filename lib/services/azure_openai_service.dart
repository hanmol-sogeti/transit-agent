/// Azure OpenAI-integration för ReseAgenten
///
/// Hanterar chat-completions med function-calling (MCP-verktyg).
/// Delar aldrig API-nyckeln till loggar.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../config/env_config.dart';

final _log = Logger('AzureOpenAiService');

class AzureOpenAiService {
  AzureOpenAiService() : _config = EnvConfig.instance;

  final EnvConfig _config;
  final _httpClient = http.Client();

  Uri get _chatEndpoint {
    // Ensure endpoint always ends with / before appending path segments.
    final base = _config.azureOpenAiEndpoint.endsWith('/')
        ? _config.azureOpenAiEndpoint
        : '${_config.azureOpenAiEndpoint}/';
    return Uri.parse(
      '${base}openai/deployments/${_config.azureOpenAiModel}'
      '/chat/completions'
      '?api-version=${_config.azureOpenAiApiVersion}',
    );
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'api-key': _config.azureOpenAiKey,
      };

  // ─── Chat completion med funktion-anrop ──────────────────────────────────

  /// Skicka en chatt-förfrågan med valfria verktygs-definitioner.
  Future<OpenAiResponse> chatCompletion({
    required List<OpenAiMessage> messages,
    List<OpenAiTool> tools = const [],
    double temperature = 0.3,
    int maxTokens = 2048,
    String? toolChoice,
  }) async {
    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
    if (tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
      if (toolChoice != null) body['tool_choice'] = toolChoice;
    }

    _log.fine(
      'Skickar chat-begäran: ${messages.length} meddelanden, '
      '${tools.length} verktyg.',
    );

    try {
      final response = await _httpClient
          .post(
            _chatEndpoint,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return OpenAiResponse.fromJson(data);
      }
      _log.warning(
        'Azure OpenAI svarade med statuskod ${response.statusCode}.',
      );
      throw OpenAiException(
        'Azure OpenAI returnerade statuskod ${response.statusCode}. '
        'Kontrollera konfigurationen.',
      );
    } on OpenAiException {
      rethrow;
    } catch (e) {
      _log.severe('Kommunikationsfel med Azure OpenAI: $e');
      throw OpenAiException(
        'Kunde inte nå Azure OpenAI. Kontrollera nätverket och konfigurationen.',
      );
    }
  }

  /// Enkel sanitetskontroll – skickar ett litet meddelande på svenska.
  Future<bool> sanityCheck() async {
    try {
      final resp = await chatCompletion(
        messages: [
          OpenAiMessage.user('Svara kortfattat på svenska: Hej!'),
        ],
        maxTokens: 50,
      );
      return resp.content?.isNotEmpty ?? false;
    } catch (e) {
      _log.warning('Sanitetskontroll Azure OpenAI misslyckades: $e');
      return false;
    }
  }

  void dispose() => _httpClient.close();
}

// ─── Datamodeller ────────────────────────────────────────────────────────────

class OpenAiMessage {
  const OpenAiMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls,
    this.name,
  });

  final String role;
  final String? content;
  final String? toolCallId;
  final List<Map<String, dynamic>>? toolCalls;
  final String? name;

  factory OpenAiMessage.system(String content) =>
      OpenAiMessage(role: 'system', content: content);
  factory OpenAiMessage.user(String content) =>
      OpenAiMessage(role: 'user', content: content);
  factory OpenAiMessage.assistant(String content) =>
      OpenAiMessage(role: 'assistant', content: content);
  factory OpenAiMessage.toolResult(
          String toolCallId, String result) =>
      OpenAiMessage(
        role: 'tool',
        content: result,
        toolCallId: toolCallId,
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'role': role};
    if (content != null) m['content'] = content;
    if (toolCallId != null) m['tool_call_id'] = toolCallId;
    if (toolCalls != null) m['tool_calls'] = toolCalls;
    if (name != null) m['name'] = name;
    return m;
  }
}

class OpenAiTool {
  const OpenAiTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

class OpenAiResponse {
  const OpenAiResponse({
    required this.id,
    this.content,
    this.toolCalls,
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
  });

  final String id;
  final String? content;
  final List<OpenAiToolCallResponse>? toolCalls;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;

  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  factory OpenAiResponse.fromJson(Map<String, dynamic> json) {
    final choice =
        (json['choices'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
    final message = choice?['message'] as Map<String, dynamic>?;
    final rawToolCalls =
        message?['tool_calls'] as List<dynamic>?;
    final usage = json['usage'] as Map<String, dynamic>?;
    return OpenAiResponse(
      id: json['id']?.toString() ?? '',
      content: message?['content']?.toString(),
      finishReason: choice?['finish_reason']?.toString(),
      promptTokens: usage?['prompt_tokens'] as int?,
      completionTokens: usage?['completion_tokens'] as int?,
      toolCalls: rawToolCalls
          ?.map((t) => OpenAiToolCallResponse.fromJson(
                t as Map<String, dynamic>,
              ))
          .toList(),
    );
  }
}

class OpenAiToolCallResponse {
  const OpenAiToolCallResponse({
    required this.id,
    required this.functionName,
    required this.arguments,
  });

  final String id;
  final String functionName;
  final Map<String, dynamic> arguments;

  factory OpenAiToolCallResponse.fromJson(Map<String, dynamic> json) {
    final func = json['function'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic> args = {};
    try {
      final rawArgs = func['arguments']?.toString() ?? '{}';
      args = jsonDecode(rawArgs) as Map<String, dynamic>;
    } catch (_) {}
    return OpenAiToolCallResponse(
      id: json['id']?.toString() ?? '',
      functionName: func['name']?.toString() ?? '',
      arguments: args,
    );
  }
}

class OpenAiException implements Exception {
  const OpenAiException(this.message);
  final String message;

  @override
  String toString() => 'OpenAiException: $message';
}
