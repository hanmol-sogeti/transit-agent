/// MCP-verktyg: PlanRoute
library;

import 'package:logging/logging.dart';
import '../../models/models.dart';
import '../../services/trafiklab_service.dart';
import 'mcp_tool.dart';

final _log = Logger('PlanRouteTool');

class PlanRouteTool implements McpTool {
  PlanRouteTool(this._trafiklab);

  final TrafiklabService _trafiklab;

  @override
  String get name => 'PlanRoute';

  @override
  String get description =>
      'Planera kollektivtrafikresor från en startpunkt till en destination. '
      'Returnerar de tre bästa rutterna med tid, byte och plattformsinformation.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'origin_id': {
            'type': 'string',
            'description': 'Hållplats-ID för startpunkt (från SearchStops).',
          },
          'destination_id': {
            'type': 'string',
            'description': 'Hållplats-ID för destination (från SearchStops).',
          },
          'datetime': {
            'type': 'string',
            'description':
                'ISO-8601 datum/tid för avresa (utelämna för nu).',
          },
          'arrival_time': {
            'type': 'boolean',
            'description': 'Om true: datetime är ankomsttid. Standard: false.',
          },
          'max_transfers': {
            'type': 'integer',
            'description': 'Max antal byten (valfritt filter).',
          },
          'accessible_only': {
            'type': 'boolean',
            'description': 'Filtrera på rullstolsanpassade resor.',
          },
        },
        'required': ['origin_id', 'destination_id'],
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final originId = args['origin_id']?.toString() ?? '';
    final destId = args['destination_id']?.toString() ?? '';
    final arrivalTime = args['arrival_time'] as bool? ?? false;
    final maxTransfers = args['max_transfers'] as int?;
    final accessibleOnly = args['accessible_only'] as bool? ?? false;

    DateTime? dt;
    if (args['datetime'] != null) {
      try {
        dt = DateTime.parse(args['datetime'].toString());
      } catch (_) {
        dt = null;
      }
    }

    _log.fine('PlanRoute: $originId -> $destId dt=$dt');

    List<TransitRoute> routes;
    try {
      routes = await _trafiklab.planRoutes(
        originId,
        destId,
        dateTime: dt,
        arrivalTime: arrivalTime,
        numRoutes: 5,
      );
    } catch (e) {
      return {'error': 'Kunde inte planera resa: $e'};
    }

    // Tillämpa filter
    if (maxTransfers != null) {
      routes = routes
          .where((r) => r.transfers <= maxTransfers)
          .toList();
    }
    if (accessibleOnly) {
      routes = routes.where((r) => r.hasWheelchairAccess).toList();
    }

    if (routes.isEmpty) {
      return {
        'error': 'Inga resor hittades med de givna filtren. '
            'Prova att ändra datum, tid eller filter.',
      };
    }

    final top3 = routes.take(3).toList();
    return {
      'routes': top3.asMap().entries.map((e) {
        final r = e.value;
        return {
          'index': e.key + 1,
          'id': r.id,
          'departure': r.departure?.toIso8601String(),
          'arrival': r.arrival?.toIso8601String(),
          'duration_minutes': r.totalDuration.inMinutes,
          'duration_label': r.durationLabel,
          'transfers': r.transfers,
          'price_sek': r.price,
          'legs': r.legs.map((l) => {
                'mode': l.mode.name,
                'line': l.line,
                'direction': l.direction,
                'platform': l.platform,
                'origin': l.origin.name,
                'destination': l.destination.name,
                'departure': l.departure.toIso8601String(),
                'arrival': l.arrival.toIso8601String(),
                'delay_minutes': l.delayMinutes,
                'realtime': l.realtime,
              }).toList(),
        };
      }).toList(),
      'count': top3.length,
    };
  }
}
