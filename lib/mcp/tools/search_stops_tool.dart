/// MCP-verktyg för ReseAgenten
///
/// Verktyget SearchStops: löser adress/ort till hållplatskandidater.
library;

import 'package:logging/logging.dart';
import '../../models/models.dart';
import '../../services/trafiklab_service.dart';
import '../../services/location_service.dart';
import 'mcp_tool.dart';

final _log = Logger('SearchStopsTool');

class SearchStopsTool implements McpTool {
  SearchStopsTool(this._trafiklab, this._location);

  final TrafiklabService _trafiklab;
  final LocationService _location;

  @override
  String get name => 'SearchStops';

  @override
  String get description =>
      'Hitta hållplatser nära en adress, ett ortnamn eller nuvarande plats. '
      'Returnerar primär hållplats och två alternativ med koordinater och avstånd.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Adress, ortnamn (t.ex. Flogsta, Stora Torget) eller '
                '"nuvarande plats" för GPS-plats.',
          },
          'radius_meters': {
            'type': 'integer',
            'description': 'Sökradius i meter (standard 500).',
          },
        },
        'required': ['query'],
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final query = args['query']?.toString() ?? '';
    final radius = (args['radius_meters'] as num?)?.toInt() ?? 500;
    _log.fine('SearchStops: query="$query" radius=$radius');

    List<Stop> stops;

    if (query.toLowerCase().contains('nuvarande plats') ||
        query.toLowerCase().contains('min plats') ||
        query.toLowerCase().contains('min position')) {
      final pos = await _location.getCurrentLocation();
      if (pos == null) {
        return {
          'error': 'Kunde inte hämta nuvarande plats. '
              'Kontrollera platsbehörigheter.',
        };
      }
      stops = await _trafiklab.nearbyStops(pos, radiusMeters: radius);
    } else {
      // Sök platskandidater
      final candidates = await _trafiklab.searchLocation(query);
      if (candidates.isEmpty) {
        return {
          'error': 'Hittade inga hållplatser för "$query". '
              'Försök med ett annat namn eller adress.',
        };
      }
      // Ta den bäst matchande kandidaten och sök omgivande hållplatser
      final primary = candidates.first;
      stops = await _trafiklab.nearbyStops(
        primary.position,
        radiusMeters: radius,
      );
      // Om inga hållplatser nära, returnera sökresultaten
      if (stops.isEmpty) stops = candidates;
    }

    if (stops.isEmpty) {
      return {
        'error': 'Inga hållplatser hittades inom $radius meter från "$query".',
      };
    }

    final primary = stops.first;
    final alternatives = stops.skip(1).take(2).toList();

    return {
      'primary': _stopToJson(primary),
      'alternatives': alternatives.map(_stopToJson).toList(),
      'count': stops.length,
    };
  }

  Map<String, dynamic> _stopToJson(Stop s) => {
        'id': s.id,
        'name': s.name,
        'lat': s.position.latitude,
        'lon': s.position.longitude,
        if (s.distanceMeters != null)
          'distance_meters': s.distanceMeters!.round(),
        'accessible': s.accessible,
      };
}
