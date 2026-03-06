/// MCP-verktyg: RenderMap
library;

import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import 'mcp_tool.dart';

/// RenderMap producerar ett MapViewModel som flutter_map-widgeten renderar.
class RenderMapTool implements McpTool {
  RenderMapTool(this._resolveRoute);

  final Future<TransitRoute?> Function(String routeId) _resolveRoute;

  @override
  String get name => 'RenderMap';

  @override
  String get description =>
      'Skapar kartvy med start- och slutpunkt samt reseled. '
      'Returnerar ett kartkonfigurationsObjekt för visning i UI.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'route_id': {
            'type': 'string',
            'description': 'Rutt-ID att visa på kartan.',
          },
          'zoom_to_start': {
            'type': 'boolean',
            'description': 'Zooma in på startpunkten. Standard false.',
          },
          'show_walking_legs': {
            'type': 'boolean',
            'description': 'Visa gångdelar (streckad linje). Standard true.',
          },
        },
        'required': ['route_id'],
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final routeId = args['route_id']?.toString() ?? '';
    final zoomToStart = args['zoom_to_start'] as bool? ?? false;
    final showWalking = args['show_walking_legs'] as bool? ?? true;

    final route = await _resolveRoute(routeId);
    if (route == null) {
      return {'error': 'Rutt $routeId hittades inte. Kör PlanRoute igen.'};
    }

    final allPoints = <Map<String, dynamic>>[];
    final legs = route.legs;

    for (final leg in legs) {
      if (!showWalking && leg.mode == TransportMode.walk) continue;
      final points = leg.geometry.isNotEmpty
          ? leg.geometry
          : [leg.origin.position, leg.destination.position];
      allPoints.addAll(points.map((p) => {'lat': p.latitude, 'lon': p.longitude}));
    }

    // Beräkna kartcentrum
    LatLng center;
    if (zoomToStart && route.origin != null) {
      center = route.origin!.position;
    } else if (allPoints.isNotEmpty) {
      final avgLat = allPoints
              .map((p) => p['lat'] as double)
              .reduce((a, b) => a + b) /
          allPoints.length;
      final avgLon = allPoints
              .map((p) => p['lon'] as double)
              .reduce((a, b) => a + b) /
          allPoints.length;
      center = LatLng(avgLat, avgLon);
    } else {
      center = const LatLng(59.8586, 17.6389); // Uppsala centrum
    }

    return {
      'route_id': routeId,
      'center': {'lat': center.latitude, 'lon': center.longitude},
      'zoom': zoomToStart ? 16.0 : 13.0,
      'origin': route.origin != null
          ? {
              'name': route.origin!.name,
              'lat': route.origin!.position.latitude,
              'lon': route.origin!.position.longitude,
            }
          : null,
      'destination': route.destination != null
          ? {
              'name': route.destination!.name,
              'lat': route.destination!.position.latitude,
              'lon': route.destination!.position.longitude,
            }
          : null,
      'polyline': allPoints,
      'legs': legs.map((l) => {
            'mode': l.mode.name,
            'line': l.line,
            'walking': l.mode == TransportMode.walk,
            'points': (l.geometry.isNotEmpty
                    ? l.geometry
                    : [l.origin.position, l.destination.position])
                .map((p) => {'lat': p.latitude, 'lon': p.longitude})
                .toList(),
          }).toList(),
      'action': 'show_map',
    };
  }
}
