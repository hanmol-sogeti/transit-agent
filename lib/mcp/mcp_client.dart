/// MCP-klient – koordinerar LLM-anrop och verktygskörning
///
/// Fungerar som orchestrator: tar emot användarens meddelanden,
/// skickar dem till Azure OpenAI med verktygsdefinitioner och
/// kör de verktygsanrop som LLM begär.
library;

import 'dart:convert';
import 'package:latlong2/latlong.dart';
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

/// Systemmeddelande på svenska – styr assistentens beteende.
const _systemPrompt = '''
Du är ReseAgenten – en hjälpsam kollektivtrafikassistent för Sverige.
Du hjälper användare att hitta hållplatser, planera resor, kolla avgångar och boka biljetter.
Svara alltid på svenska, koncist och vänligt.
Använd de tillgängliga verktygen för att hämta aktuell data.
Förklara kortfattat vad du gör (t.ex. "Söker hållplatser nära Flogsta...").
Vid bokning: visa alltid pris, rutt och avbokningsinfo INNAN du bekräftar.
Om du inte är säker på orten – fråga användaren om klargörande.
''';

class McpClient {
  McpClient({
    required AzureOpenAiService openAi,
    required TrafiklabService trafiklab,
    required LocationService location,
    required BookingService booking,
  })  : _openAi = openAi {
    _tools = {
      'SearchStops': SearchStopsTool(trafiklab, location),
      'PlanRoute': PlanRouteTool(trafiklab),
      'RealtimeDepartures': RealtimeDeparturesTool(trafiklab),
      'BookTicket': BookTicketTool(booking, _resolveRoute),
      'RenderMap': RenderMapTool(_resolveRoute),
      'Config': ConfigTool(),
    };
  }

  final AzureOpenAiService _openAi;
  late final Map<String, McpTool> _tools;
  final _uuid = const Uuid();

  // Session-scratchpad: hållplatskandidater och ruttkanidater
  final Map<String, TransitRoute> _routeCache = {};
  final List<ChatMessage> _history = [];
  final List<McpToolCall> _toolCallLog = [];

  List<ChatMessage> get history => List.unmodifiable(_history);
  List<McpToolCall> get toolCallLog => List.unmodifiable(_toolCallLog);

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
      OpenAiMessage.system(_systemPrompt),
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
            // Om PlanRoute returnerade rutter, cacha dem
            if (tc.functionName == 'PlanRoute' && result['routes'] != null) {
              _cacheRoutesFromPlanResult(result, tc.arguments);
            }
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

    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: finalContent.isNotEmpty
          ? finalContent
          : 'Jag kunde inte bearbeta din förfrågan. Försök igen.',
      timestamp: DateTime.now(),
      toolCalls: _toolCallLog.isNotEmpty
          ? _toolCallLog.sublist(
              _toolCallLog.length > 5
                  ? _toolCallLog.length - 5
                  : 0)
          : [],
    );
    _history.add(assistantMsg);
    return assistantMsg;
  }

  void _cacheRoutesFromPlanResult(
    Map<String, dynamic> result,
    Map<String, dynamic> args,
  ) {
    final routes = result['routes'] as List<dynamic>? ?? [];
    for (final r in routes) {
      final rm = r as Map<String, dynamic>;
      final id = rm['id']?.toString() ?? '';
      if (id.isNotEmpty && !_routeCache.containsKey(id)) {
        // Bygg en minimal TransitRoute från JSON-svaret
        final legs = (rm['legs'] as List<dynamic>? ?? []).map((l) {
          final lm = l as Map<String, dynamic>;
          final originStop = Stop(
            id: '',
            name: lm['origin']?.toString() ?? '',
            position: const LatLng(0, 0),
          );
          final destStop = Stop(
            id: '',
            name: lm['destination']?.toString() ?? '',
            position: const LatLng(0, 0),
          );
          DateTime dep = DateTime.now(), arr = DateTime.now();
          try { dep = DateTime.parse(lm['departure'].toString()); } catch (_) {}
          try { arr = DateTime.parse(lm['arrival'].toString()); } catch (_) {}
          final mode = TransportMode.values.firstWhere(
            (m) => m.name == lm['mode']?.toString(),
            orElse: () => TransportMode.unknown,
          );
          return Leg(
            origin: originStop,
            destination: destStop,
            departure: dep,
            arrival: arr,
            mode: mode,
            line: lm['line']?.toString(),
            direction: lm['direction']?.toString(),
            platform: lm['platform']?.toString(),
            realtime: lm['realtime'] as bool? ?? false,
            delayMinutes: lm['delay_minutes'] as int? ?? 0,
          );
        }).toList();
        final durationMin = (rm['duration_minutes'] as num?)?.toInt() ?? 0;
        final transfers = (rm['transfers'] as num?)?.toInt() ?? 0;
        final price = (rm['price_sek'] as num?)?.toDouble();
        final route = TransitRoute(
          id: id,
          legs: legs,
          totalDuration: Duration(minutes: durationMin),
          transfers: transfers,
          price: price,
        );
        _routeCache[id] = route;
      }
    }
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
