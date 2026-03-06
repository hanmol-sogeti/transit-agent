/// Routing-tjänst: gångetapper via OSRM eller Valhalla
///
/// Används för att rita ut gångvägar till/från hållplatser
/// när Trafiklab inte tillhandahåller geometri.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import '../config/env_config.dart';

final _log = Logger('RoutingService');

class RoutingService {
  RoutingService() : _config = EnvConfig.instance;

  final EnvConfig _config;
  final _httpClient = http.Client();

  /// Beräkna gångväg between [origin] och [destination].
  /// Returnerar en lista med koordinatpunkter för polylinjen.
  Future<RoutingResult> walkingRoute(LatLng origin, LatLng destination) async {
    final endpoint = _config.routingEndpoint;
    // Stöd båda OSRM (route/v1/foot) och Valhalla (/route) format
    if (endpoint.contains('valhalla') || endpoint.contains('/route')) {
      return _valhallaRoute(origin, destination, endpoint);
    }
    return _osrmRoute(origin, destination, endpoint);
  }

  Future<RoutingResult> _osrmRoute(
    LatLng origin,
    LatLng dest,
    String baseUrl,
  ) async {
    final url =
        '$baseUrl/route/v1/foot/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson';
    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw RoutingException('OSRM svarade med ${response.statusCode}.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        throw RoutingException('Ingen gångväg hittades.');
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = (geometry['coordinates'] as List<dynamic>)
          .map((c) {
            final pair = c as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          })
          .toList();
      final distanceM = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSec = (route['duration'] as num?)?.toDouble() ?? 0;
      return RoutingResult(
        points: coords,
        distanceMeters: distanceM,
        durationSeconds: durationSec,
      );
    } on RoutingException {
      rethrow;
    } catch (e) {
      _log.warning('OSRM routingfel: $e');
      throw RoutingException('Kunde inte beräkna gångväg (OSRM).');
    }
  }

  Future<RoutingResult> _valhallaRoute(
    LatLng origin,
    LatLng dest,
    String baseUrl,
  ) async {
    final body = jsonEncode({
      'locations': [
        {'lon': origin.longitude, 'lat': origin.latitude},
        {'lon': dest.longitude, 'lat': dest.latitude},
      ],
      'costing': 'pedestrian',
      'units': 'km',
    });
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/route'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw RoutingException('Valhalla svarade med ${response.statusCode}.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final trip = data['trip'] as Map<String, dynamic>?;
      final legs = trip?['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) {
        throw RoutingException('Ingen gångväg hittades.');
      }
      final points = <LatLng>[];
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final shape = legMap['shape']?.toString() ?? '';
        points.addAll(_decodePolyline(shape));
      }
      final summary = trip?['summary'] as Map<String, dynamic>?;
      return RoutingResult(
        points: points,
        distanceMeters: ((summary?['length'] as num?)?.toDouble() ?? 0) * 1000,
        durationSeconds: (summary?['time'] as num?)?.toDouble() ?? 0,
      );
    } on RoutingException {
      rethrow;
    } catch (e) {
      _log.warning('Valhalla routingfel: $e');
      throw RoutingException('Kunde inte beräkna gångväg (Valhalla).');
    }
  }

  /// Avkoda Valhalla encoded polyline (Google format).
  List<LatLng> _decodePolyline(String encoded, {int precision = 6}) {
    final factor = precision == 6 ? 1e6 : 1e5;
    final result = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final dlat = ((result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1));
      lat += dlat;
      shift = 0;
      result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final dlng = ((result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1));
      lng += dlng;
      result.add(LatLng(lat / factor, lng / factor));
    }
    return result;
  }

  void dispose() => _httpClient.close();
}

class RoutingResult {
  const RoutingResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  Duration get duration => Duration(seconds: durationSeconds.round());
  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;

  @override
  String toString() => 'RoutingException: $message';
}
