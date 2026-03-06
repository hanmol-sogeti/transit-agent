/// MCP-klient – koordinerar LLM-anrop och verktygskörning
///
/// Fungerar som orchestrator: tar emot användarens meddelanden,
/// skickar dem till Azure OpenAI med verktygsdefinitioner och
/// kör de verktygsanrop som LLM begär.
library;

import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/azure_openai_service.dart';
import '../services/trafiklab_service.dart';
import '../services/location_service.dart';
import '../services/booking_service.dart';
import 'tools/mcp_tool.dart';
import 'tools/search_stops_tool.dart';
import 'tools/plan_route_tool.dart';
import 'tools/realtime_departures_tool.dart';
import 'tools/book_ticket_tool.dart';
import 'tools/render_map_tool.dart';
import 'tools/config_tool.dart';

final _log = Logger('McpClient');

/// Bygg systemmeddelande — inkluderar användarprofil om tillgänglig.
String _buildSystemPrompt(UserProfile? profile) {
  final userCtx = StringBuffer();
  if (profile != null && profile.hasProfile) {
    if (profile.name.isNotEmpty) {
      userCtx.write('Användarens namn är ${profile.name}. ');
    }
    if (profile.homeAddress.isNotEmpty) {
      userCtx.write(
        'Användarens hemadress är "${profile.homeAddress}". '
        'VIKTIGT: Om användaren inte explicit anger en startplats för resan, '
        'använd ALLTID hemadress som startpunkt. Detta gäller alla formuleringar '
        'såsom: "Jag vill åka till X", "Hur kommer jag till X?", "Planera resa '
        'till X", "Ta mig till X", "Hur lång tid tar det till X?" – alltså '
        'ALLTID när en destination nämns utan att en startplats anges. '
        'Sök automatiskt närmaste hållplats till hemadress via SearchStops. '
        'Fråga ALDRIG om startplats om hemadress är känd – anta den som standard. ',
      );
    }
  }
  return '''
Du är ReseAgenten – en hjälpsam kollektivtrafikassistent för Sverige.
${userCtx.toString()}
Du hjälper användare att hitta hållplatser, planera resor, kolla avgångar och boka biljetter.
Svara alltid på svenska, koncist och vänligt.
Använd de tillgängliga verktygen för att hämta aktuell data.
Förklara kortfattat vad du gör (t.ex. "Söker hållplatser nära Flogsta...").

När destination är ett område med flera hållplatser (t.ex. "Flogsta"):
1. Sök hållplatser i området med SearchStops.
2. Välj den hållplats som ger kortast restid som slutdestination.
3. Lista topp 3 alternativa hållplatser i svaret så användaren kan välja.

Vid bokning: visa alltid pris, rutt och avbokningsinfo INNAN du bekräftar.
Om du inte är säker på orten – fråga användaren om klargjörande.

Avsluta ALLTID varje svar med exakt denna rad (sista raden, inget efteråt):
<!--chips:["Förslag1","Förslag2","Förslag3"]-->
Välj 2–4 korta, klickbara uppföljningsförslag anpassade till konversationen:
- Resa planerad: ["Boka resa","Nästa avgång","Visa karta","Annan tid"]
- Hållplats nämnd: ["Avgångstavla","Planera resa härifrån","Närmaste hållplatser"]
- Generellt: ["Planera resa","Visa avgångar","Mina bokningar"]
''';
}

class McpClient {
  McpClient({
    required AzureOpenAiService openAi,
    required TrafiklabService trafiklab,
    required LocationService location,
    required BookingService booking,
  })  : _openAi = openAi {
    _tools = {
      'SearchStops': SearchStopsTool(trafiklab, location),
      'PlanRoute': PlanRouteTool(
        trafiklab,
        onRoutes: (routes) {
          for (final r in routes) {
            _routeCache[r.id] = r;
          }
        },
      ),
      'RealtimeDepartures': RealtimeDeparturesTool(trafiklab),
      'BookTicket': BookTicketTool(booking, _resolveRoute),
      'RenderMap': RenderMapTool(_resolveRoute),
      'Config': ConfigTool(),
    };
  }

  final AzureOpenAiService _openAi;
  late final Map<String, McpTool> _tools;
  final _uuid = const Uuid();
  UserProfile? _userProfile;

  void setUserProfile(UserProfile profile) {
    _userProfile = profile;
  }

  // Session-scratchpad: hållplatskandidater och ruttkanidater
  final Map<String, TransitRoute> _routeCache = {};
  final List<ChatMessage> _history = [];
  final List<McpToolCall> _toolCallLog = [];

  List<ChatMessage> get history => List.unmodifiable(_history);
  List<McpToolCall> get toolCallLog => List.unmodifiable(_toolCallLog);
  List<TransitRoute> get cachedRoutes => _routeCache.values.toList();

  /// Extrahera suggestion-chips från AI-svar och returnera rensat innehåll.
  static final RegExp _chipsRe =
      RegExp(r'<!--chips:(\[.*?\])-->', dotAll: false);

  (String, List<String>) _extractChips(String content) {
    final match = _chipsRe.firstMatch(content);
    if (match == null) return (content.trimRight(), const []);
    try {
      final raw = jsonDecode(match.group(1)!) as List<dynamic>;
      final chips = raw.cast<String>();
      final cleaned =
          content.replaceAll(match.group(0)!, '').trimRight();
      return (cleaned, chips);
    } catch (_) {
      return (
        content.replaceAll(match.group(0)!, '').trimRight(),
        const [],
      );
    }
  }

  /// Registrera en rutt i cache (anropas av PlanRoute-logiken).
  void cacheRoute(TransitRoute route) {
    _routeCache[route.id] = route;
  }

  Future<TransitRoute?> _resolveRoute(String routeId) async =>
      _routeCache[routeId];

  // ─── Huvud-chatt ─────────────────────────────────────────────────────────

  /// Skicka ett användarmeddelande och returnera assistentsvaret.
  /// [onToolCall] anropas vid varje verktygskörning (för debug-panel).
  Future<ChatMessage> sendMessage(
    String userText, {
    void Function(McpToolCall call)? onToolCall,
  }) async {
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: userText,
      timestamp: DateTime.now(),
    );
    _history.add(userMsg);

    // Bygg OpenAI-meddelanden
    final messages = <OpenAiMessage>[
      OpenAiMessage.system(_buildSystemPrompt(_userProfile)),
      ..._history.map(_chatMsgToOpenAi),
    ];

    // Konvertera verktyg
    final tools = _tools.values
        .map((t) => OpenAiTool(
              name: t.name,
              description: t.description,
              parameters: t.parametersSchema,
            ))
        .toList();

    // Agentkörningsloop: LLM kan begära flera verktygskörningar
    OpenAiResponse resp;
    String finalContent = '';

    for (var maxIter = 0; maxIter < 8; maxIter++) {
      resp = await _openAi.chatCompletion(
        messages: messages,
        tools: tools,
      );

      if (!resp.hasToolCalls) {
        finalContent = resp.content ?? '';
        break;
      }


      // ── Kör verktygen ────────────────────────────────────────────────────
      final toolCallMsgs = <Map<String, dynamic>>[];
      for (final tc in resp.toolCalls!) {
        toolCallMsgs.add({
          'id': tc.id,
          'type': 'function',
          'function': {
            'name': tc.functionName,
            'arguments': jsonEncode(tc.arguments),
          },
        });
      }
      // Lägg till assistentmeddelande med tool_calls
      messages.add(OpenAiMessage(
        role: 'assistant',
        content: resp.content,
        toolCalls: toolCallMsgs,
      ));

      for (final tc in resp.toolCalls!) {
        final tool = _tools[tc.functionName];
        final startMs = DateTime.now().millisecondsSinceEpoch;
        Map<String, dynamic> result = {};
        String? error;

        if (tool == null) {
          error = 'Okänt verktyg: ${tc.functionName}';
          result = {'error': error};
          _log.warning(error);
        } else {
          try {
            result = await tool.execute(tc.arguments);
            // PlanRoute now caches routes itself via onRoutes callback
          } catch (e) {
            error = 'Fel vid körning av ${tc.functionName}: $e';
            result = {'error': error};
            _log.warning(error);
          }
        }

        final durationMs =
            DateTime.now().millisecondsSinceEpoch - startMs;
        final toolCall = McpToolCall(
          toolName: tc.functionName,
          arguments: tc.arguments,
          result: result,
          durationMs: durationMs,
          error: error,
        );
        _toolCallLog.add(toolCall);
        onToolCall?.call(toolCall);

        messages.add(OpenAiMessage.toolResult(
          tc.id,
          jsonEncode(result),
        ));
      }
    }

    final (cleanContent, chips) = _extractChips(
      finalContent.isNotEmpty
          ? finalContent
          : 'Jag kunde inte bearbeta din förfrågan. Försök igen.',
    );
    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: cleanContent,
      timestamp: DateTime.now(),
      toolCalls: _toolCallLog.isNotEmpty
          ? _toolCallLog.sublist(
              _toolCallLog.length > 5
                  ? _toolCallLog.length - 5
                  : 0)
          : [],
      suggestions: chips.isNotEmpty ? chips : null,
    );
    _history.add(assistantMsg);
    return assistantMsg;
  }

  OpenAiMessage _chatMsgToOpenAi(ChatMessage msg) {
    switch (msg.role) {
      case ChatRole.user:
        return OpenAiMessage.user(msg.content);
      case ChatRole.assistant:
        return OpenAiMessage.assistant(msg.content);
      case ChatRole.system:
        return OpenAiMessage.system(msg.content);
      case ChatRole.tool:
        return OpenAiMessage(
          role: 'tool',
          content: msg.content,
          toolCallId: msg.id,
        );
    }
  }

  /// Rensa konversationshistorik.
  void clearHistory() {
    _history.clear();
    _toolCallLog.clear();
    _routeCache.clear();
  }

  /// Returnerar alla registrerade verktyg.
  List<McpTool> get registeredTools => _tools.values.toList();
}
