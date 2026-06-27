import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

/// Result of a location attempt.
enum LocationStatus { ok, denied, serviceDisabled, error }

class LocationResult {
  final LocationStatus status;
  final Place? place;
  const LocationResult(this.status, [this.place]);
}

/// Wraps geolocator: permission flow + a single position read.
class LocationService {
  /// Try to get the user's current location. Returns a [LocationResult];
  /// on success [place] is labelled "Current location".
  Future<LocationResult> getCurrent() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.denied);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return LocationResult(
        LocationStatus.ok,
        Place(
          name: 'Current location',
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
      );
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }
}
