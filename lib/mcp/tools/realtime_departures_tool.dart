/// MCP-verktyg: RealtimeDepartures
library;

import 'package:logging/logging.dart';
import '../../services/trafiklab_service.dart';
import 'mcp_tool.dart';

final _log = Logger('RealtimeDeparturesTool');

class RealtimeDeparturesTool implements McpTool {
  RealtimeDeparturesTool(this._trafiklab);

  final TrafiklabService _trafiklab;

  @override
  String get name => 'RealtimeDepartures';

  @override
  String get description =>
      'Hämta realtidsavgångar för en hållplats. Visar förseningar och fordonets status.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'stop_id': {
            'type': 'string',
            'description': 'Hållplats-ID (från SearchStops).',
          },
          'max_results': {
            'type': 'integer',
            'description': 'Max antal avgångar (standard 10).',
          },
        },
        'required': ['stop_id'],
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final stopId = args['stop_id']?.toString() ?? '';
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 10;

    _log.fine('RealtimeDepartures: stop=$stopId');

    try {
      final departures = await _trafiklab.departures(
        stopId,
        maxResults: maxResults,
      );
      if (departures.isEmpty) {
        return {'message': 'Inga avgångar hittades för denna hållplats just nu.'};
      }
      return {
        'stop_id': stopId,
        'departures': departures.map((d) => {
              'line': d.line,
              'direction': d.direction,
              'scheduled_time': d.scheduledTime.toIso8601String(),
              'expected_time': d.expectedTime?.toIso8601String(),
              'delay_minutes': d.delayMinutes,
              'delay_label': d.delayLabel,
              'on_time': d.isOnTime,
              'cancelled': d.cancelled,
              'platform': d.platform,
            }).toList(),
        'count': departures.length,
      };
    } catch (e) {
      return {'error': 'Kunde inte hämta avgångar: $e'};
    }
  }
}
