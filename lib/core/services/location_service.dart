import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Customer coordinates used to scope discovery and delivery pricing.
class UserLocation {
  const UserLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Finite, in range, and not the (0, 0) "never set" value.
  bool get isUsable {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude.isInfinite || longitude.isInfinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return !(latitude == 0 && longitude == 0);
  }

  /// Great-circle distance to [other], in metres.
  double metersTo(UserLocation other) {
    const earthRadius = 6371000.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
  }

  @override
  bool operator ==(Object other) =>
      other is UserLocation &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
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

  /// The device position.
  ///
  /// With [prompt] false the OS permission dialog is never shown: a background
  /// refresh must not interrupt the customer. A position is still returned when
  /// permission was already granted.
  Future<UserLocation> current({bool prompt = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationFailure.serviceDisabled,
        'Location services are turned off. Turn them on to see restaurants near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && prompt) {
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

    UserLocation? fix;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      fix = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // A timeout is common indoors; the last known fix is better than nothing.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        fix = UserLocation(latitude: last.latitude, longitude: last.longitude);
      }
    }
    // A device that reports (0, 0) or NaN has no fix: never pass it on as a
    // place, or restaurants appear "0 km" away and orders go to the ocean.
    if (fix == null || !fix.isUsable) {
      throw const LocationException(
        LocationFailure.unavailable,
        'Unable to determine your location. Please try again.',
      );
    }
    return fix;
  }
}
