import 'package:geolocator/geolocator.dart';

/// Customer coordinates used to scope discovery and delivery pricing.
class UserLocation {
  const UserLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Why a location could not be obtained. Callers show the right message and
/// fall back to non-located browsing rather than blocking the app.
enum LocationFailure { serviceDisabled, permissionDenied, permanentlyDenied, unavailable }

class LocationException implements Exception {
  const LocationException(this.failure, this.message);

  final LocationFailure failure;
  final String message;

  @override
  String toString() => message;
}

/// Resolves the device's current position.
///
/// Location is optional for food endpoints: `/api/home`, `/api/restaurants`
/// and `/customer-web/cart/validate` accept requests without coordinates. The
/// grocery flow requires coordinates, so callers return an empty nearby grocery
/// view or a validation message when location is unavailable.
class LocationService {
  const LocationService();

  Future<UserLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationFailure.serviceDisabled,
        'Location services are turned off. Turn them on to see restaurants near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationFailure.permanentlyDenied,
        'Location permission is permanently denied. Enable it in system settings.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        LocationFailure.permissionDenied,
        'Location permission is required to show restaurants near you.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // A timeout is common indoors; the last known fix is better than nothing.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return UserLocation(latitude: last.latitude, longitude: last.longitude);
      }
      throw const LocationException(
        LocationFailure.unavailable,
        'Could not determine your location. Please try again.',
      );
    }
  }
}
