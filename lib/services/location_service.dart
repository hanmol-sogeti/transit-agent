/// GPS-platstjänst för ReseAgenten
library;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';

final _log = Logger('LocationService');

class LocationService {
  /// Begär och returnerar enhetens nuvarande plats.
  /// Returnerar null om tillstånd saknas eller plats ej tillgänglig.
  Future<LatLng?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          _log.info('Platstillstånd nekades av användaren.');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _log.warning('Platstillstånd permanent nekat.');
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      _log.warning('Kunde inte hämta plats: $e');
      return null;
    }
  }

  /// Beräkna avstånd i meter mellan två koordinater.
  double distanceMeters(LatLng from, LatLng to) =>
      Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
}
