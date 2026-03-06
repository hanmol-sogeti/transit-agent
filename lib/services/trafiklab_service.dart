/// Trafiklab API-integration för ReseAgenten
///
/// Hanterar ResRobot (rutt-planering, hållplatssökning, avgångstavla)
/// samt GTFS-RT realtidsinformation.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import '../config/env_config.dart';
import '../models/models.dart';

final _log = Logger('TrafiklabService');
const _baseUrl = 'https://api.resrobot.se/v2.1';
const _maxRetries = 3;
const _retryDelay = Duration(seconds: 2);

class TrafiklabService {
  TrafiklabService() : _config = EnvConfig.instance;

  final EnvConfig _config;
  final _httpClient = http.Client();

  // ─── Hållplatssökning ─────────────────────────────────────────────────────

  /// Hitta hållplatser nära en given koordinat.
  Future<List<Stop>> nearbyStops(
    LatLng position, {
    int radiusMeters = 500,
    int maxResults = 10,
  }) async {
    final params = {
      'originCoordLat': position.latitude.toString(),
      'originCoordLong': position.longitude.toString(),
      'type': 'S',
      'maxNo': maxResults.toString(),
      'r': radiusMeters.toString(),
      'format': 'json',
      'accessId': _config.trafiklabStopsKey,
    };

    final data = await _get('/location.nearbystops', params);
    final stopList = data['stopLocationOrCoordLocation'] as List<dynamic>? ?? [];
    return stopList.map(_parseStopLocation).whereType<Stop>().toList();
  }

  /// Sök hållplatser/platser via fritextsökning.
  Future<List<Stop>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    final params = {
      'input': query,
      'type': 'S',
      'maxNo': '10',
      'format': 'json',
      'accessId': _config.trafiklabStopsKey,
    };

    final data = await _get('/location.name', params);
    final stopList = data['stopLocationOrCoordLocation'] as List<dynamic>? ?? [];
    return stopList.map(_parseStopLocation).whereType<Stop>().toList();
  }

  // ─── Ruttplanering ───────────────────────────────────────────────────────

  /// Planera resa från [origin] till [destination].
  Future<List<TransitRoute>> planRoutes(
    String originId,
    String destinationId, {
    DateTime? dateTime,
    bool arrivalTime = false,
    int numRoutes = 3,
  }) async {
    final dt = dateTime ?? DateTime.now();
    final params = {
      'originId': originId,
      'destId': destinationId,
      'date': '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}',
      'time': '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}',
      'numF': numRoutes.toString(),
      'searchForArrival': arrivalTime ? '1' : '0',
      'format': 'json',
      'accessId': _config.trafiklabRouteKey,
    };

    final data = await _get('/trip', params);
    final trips = data['Trip'] as List<dynamic>? ?? [];
    return trips.asMap().entries.map((e) => _parseTrip(e.value, e.key)).toList();
  }

  // ─── Avgångstavla ────────────────────────────────────────────────────────

  /// Hämta avgångar från en hållplats.
  Future<List<RealtimeDeparture>> departures(
    String stopId, {
    int maxResults = 20,
  }) async {
    final params = {
      'id': stopId,
      'maxJourneys': maxResults.toString(),
      'format': 'json',
      'accessId': _config.trafiklabRouteKey,
    };

    final data = await _get('/departureBoard', params);
    final deps = data['Departure'] as List<dynamic>? ?? [];
    return deps.map(_parseDeparture).whereType<RealtimeDeparture>().toList();
  }

  // ─── Geo-kodning ─────────────────────────────────────────────────────────

  /// Löser en adress/ort till koordinateter och hållplatsID.
  Future<List<Stop>> geocode(String address) => searchLocation(address);

  // ─── Parsning ────────────────────────────────────────────────────────────

  Stop? _parseStopLocation(dynamic item) {
    try {
      final typedItem = item as Map<String, dynamic>;
      final stopData =
          (typedItem['StopLocation'] as Map<String, dynamic>?) ?? typedItem;
      final lat = double.tryParse(stopData['lat']?.toString() ?? '') ?? 0;
      final lon = double.tryParse(stopData['lon']?.toString() ?? '') ?? 0;
      final dist = double.tryParse(stopData['dist']?.toString() ?? '');
      return Stop(
        id: stopData['extId']?.toString() ?? stopData['id']?.toString() ?? '',
        name: stopData['name']?.toString() ?? 'Okänd hållplats',
        position: LatLng(lat, lon),
        distanceMeters: dist,
      );
    } catch (e) {
      _log.warning('Kunde inte parsa hållplatsobjekt: $e');
      return null;
    }
  }

  TransitRoute _parseTrip(dynamic tripData, int index) {
    final legs = <Leg>[];
    // ResRobot v2.1: 'Leg' is a List for multi-leg trips, a single Map for
    // single-leg trips. Normalise to List regardless.
    final legRaw = (tripData['LegList'] as Map<String, dynamic>?)?['Leg'];
    final legList = legRaw is List
        ? legRaw
        : (legRaw != null ? <dynamic>[legRaw] : <dynamic>[]);
    for (final leg in legList) {
      final parsed = _parseLeg(leg as Map<String, dynamic>);
      if (parsed != null) legs.add(parsed);
    }
    final duration = legs.fold<Duration>(
      Duration.zero,
      (acc, l) => acc + l.duration,
    );
    final transfers = (legList.length - 1).clamp(0, 99);
    return TransitRoute(
      id: 'route_$index',
      legs: legs,
      totalDuration: duration,
      transfers: transfers,
      price: _estimatePrice(legs),
    );
  }

  Leg? _parseLeg(Map<String, dynamic> data) {
    try {
      final originData = data['Origin'] as Map<String, dynamic>;
      final destData = data['Destination'] as Map<String, dynamic>;
      final depStr = '${originData['date']} ${originData['time']}';
      final arrStr = '${destData['date']} ${destData['time']}';
      final origin = Stop(
        id: originData['extId']?.toString() ?? '',
        name: originData['name']?.toString() ?? '',
        position: LatLng(
          double.tryParse(originData['lat']?.toString() ?? '') ?? 0,
          double.tryParse(originData['lon']?.toString() ?? '') ?? 0,
        ),
      );
      final dest = Stop(
        id: destData['extId']?.toString() ?? '',
        name: destData['name']?.toString() ?? '',
        position: LatLng(
          double.tryParse(destData['lat']?.toString() ?? '') ?? 0,
          double.tryParse(destData['lon']?.toString() ?? '') ?? 0,
        ),
      );
      final category = data['category']?.toString().toLowerCase() ?? '';
      final mode = _parseMode(category, data['type']?.toString());
      final points = _parseGeometry(data['Stops']);
      final realtimeFlag = data['realtimeDataAvailable'] == true ||
          data['rtDepTime'] != null;
      int delayMin = 0;
      if (realtimeFlag && data['rtDepTime'] != null) {
        try {
          final sched = DateTime.parse(depStr.replaceAll(' ', 'T'));
          final rt = DateTime.parse(
              '${originData['rtDate'] ?? originData['date']} ${data['rtDepTime']}'
                  .replaceAll(' ', 'T'));
          delayMin = rt.difference(sched).inMinutes;
        } catch (_) {}
      }
      return Leg(
        origin: origin,
        destination: dest,
        departure: DateTime.parse(depStr.replaceAll(' ', 'T')),
        arrival: DateTime.parse(arrStr.replaceAll(' ', 'T')),
        mode: mode,
        line: data['name']?.toString(),
        direction: destData['name']?.toString(),
        platform: originData['track']?.toString(),
        geometry: points,
        realtime: realtimeFlag,
        delayMinutes: delayMin,
      );
    } catch (e) {
      _log.warning('Kunde inte parsa legData: $e');
      return null;
    }
  }

  List<LatLng> _parseGeometry(dynamic stopsData) {
    if (stopsData == null) return [];
    try {
      final stopList = (stopsData as Map<String, dynamic>)['Stop']
              as List<dynamic>? ??
          [];
      return stopList.map((s) {
        final sm = s as Map<String, dynamic>;
        return LatLng(
          double.tryParse(sm['lat']?.toString() ?? '') ?? 0,
          double.tryParse(sm['lon']?.toString() ?? '') ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  RealtimeDeparture? _parseDeparture(dynamic data) {
    try {
      final dm = data as Map<String, dynamic>;
      // ResRobot v2.1: 'stop' is a plain string (stop name), id is 'stopExtId'.
      final stop = Stop(
        id: dm['stopExtId']?.toString() ?? '',
        name: dm['stop']?.toString() ?? '',
        position: const LatLng(0, 0),
      );
      final dateStr = '${dm['date']} ${dm['time']}'.replaceAll(' ', 'T');
      DateTime scheduledTime;
      try {
        scheduledTime = DateTime.parse(dateStr);
      } catch (_) {
        scheduledTime = DateTime.now();
      }
      DateTime? expectedTime;
      final rtTime = dm['rtTime']?.toString();
      if (rtTime != null) {
        try {
          expectedTime = DateTime.parse(
              '${dm['rtDate'] ?? dm['date']} $rtTime'.replaceAll(' ', 'T'));
        } catch (_) {}
      }
      final delay = expectedTime != null
          ? expectedTime.difference(scheduledTime).inMinutes
          : 0;
      return RealtimeDeparture(
        line: dm['name']?.toString() ?? dm['line']?.toString() ?? '',
        direction: dm['direction']?.toString() ?? '',
        scheduledTime: scheduledTime,
        stop: stop,
        expectedTime: expectedTime,
        delayMinutes: delay,
        cancelled: dm['cancelled'] == true,
        platform: dm['track']?.toString(),
        journeyId: dm['journeyDetailRef']?.toString(),
      );
    } catch (e) {
      _log.warning('Kunde inte parsa avgång: $e');
      return null;
    }
  }

  TransportMode _parseMode(String category, String? type) {
    if (category.contains('bus') || type == 'BUS') {
      return TransportMode.bus;
    }
    if (category.contains('train') ||
        category.contains('tåg') ||
        type == 'TRAIN') {
      return TransportMode.train;
    }
    if (category.contains('tram') || type == 'TRAM') {
      return TransportMode.tram;
    }
    if (category.contains('metro') ||
        category.contains('tunnelbana') ||
        type == 'SUBWAY') {
      return TransportMode.subway;
    }
    if (category.contains('ferry') || type == 'FERRY') {
      return TransportMode.ferry;
    }
    if (category.contains('walk') || type == 'WALK') {
      return TransportMode.walk;
    }
    return TransportMode.unknown;
  }

  double _estimatePrice(List<Leg> legs) {
    // Fiktivt pris för demo – i produktion hämtas priser från Trafiklab.
    final nonWalkLegs = legs.where((l) => l.mode != TransportMode.walk).length;
    return nonWalkLegs > 0 ? 35.0 * nonWalkLegs : 0.0;
  }

  // ─── HTTP-hjälpare ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    _log.fine('GET $path (params utan nyckel)');

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _httpClient
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          // ResRobot can return HTTP 200 but with an errorCode in the body.
          final errorCode = decoded['errorCode']?.toString();
          if (errorCode != null) {
            final errorText = decoded['errorText']?.toString() ?? errorCode;
            if (errorCode == 'API_AUTH') {
              throw TrafiklabAuthException(
                'Åtkomst nekad av Trafiklab. '
                'Kontrollera att API-nyckeln är prenumererad på ResRobot-produkterna '
                'på trafiklab.se/api. Detalj: $errorText',
              );
            }
            throw TrafiklabException('Trafiklab-fel ($errorCode): $errorText');
          }
          return decoded;
        }
        // Try to extract the API error message from the JSON body.
        String? apiError;
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          apiError = errBody['errorText']?.toString();
        } catch (_) {}
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw TrafiklabAuthException(
            'Åtkomst nekad av Trafiklab (${response.statusCode}). '
            'Kontrollera att API-nyckeln är prenumererad på ResRobot-produkterna '
            'på trafiklab.se/api.'
            '${apiError != null ? ' Detalj: $apiError' : ''}',
          );
        }
        if (response.statusCode == 429) {
          // Rate limit – vänta och försök igen
          _log.warning(
            'Rate limit (429) från Trafiklab. Försök $attempt/$_maxRetries.',
          );
          if (attempt < _maxRetries) {
            await Future.delayed(_retryDelay * attempt);
            continue;
          }
          throw TrafiklabException(
            'Trafiklab svarar för långsamt just nu (rate limit). Försök igen om ett ögonblick.',
          );
        }
        // ResRobot returns 200 with an error body for auth issues in some
        // versions; detect the errorCode field.
        throw TrafiklabException(
          'Trafiklab returnerade statuskod ${response.statusCode}.'
          '${apiError != null ? ' Detalj: $apiError' : ''}',
        );
      } on TrafiklabException {
        rethrow;
      } catch (e) {
        _log.warning('Nätverksfel försök $attempt: $e');
        if (attempt == _maxRetries) {
          throw TrafiklabException(
            'Kunde inte ansluta till Trafiklab. Kontrollera nätverksanslutningen.',
          );
        }
        await Future.delayed(_retryDelay * attempt);
      }
    }
    throw TrafiklabException('Okänt fel vid Trafiklab-anrop.');
  }

  void dispose() => _httpClient.close();
}

class TrafiklabException implements Exception {
  const TrafiklabException(this.message);
  final String message;

  @override
  String toString() => 'TrafiklabException: $message';
}

/// Thrown when the API key lacks access to a Trafiklab product.
/// Instructs the user to subscribe the key on trafiklab.se/api.
class TrafiklabAuthException extends TrafiklabException {
  const TrafiklabAuthException(super.message);

  @override
  String toString() => 'TrafiklabAuthException: $message';
}
