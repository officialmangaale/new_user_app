import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'address_form_logic.dart';

/// One GPS fix for an address pin.
class CapturedLocation {
  const CapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime capturedAt;
}

enum LocationCaptureFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationCaptureResult {
  const LocationCaptureResult.captured(CapturedLocation this.location)
    : failure = null;
  const LocationCaptureResult.failed(LocationCaptureFailure this.failure)
    : location = null;

  final CapturedLocation? location;
  final LocationCaptureFailure? failure;
}

/// Captures the device position once, when the customer asks for it.
///
/// Never called automatically: the address form works fully without it, and
/// permission is requested only from an explicit "Use current location" tap.
/// It does not track; each call is a single fix.
abstract class AddressLocationCapture {
  Future<LocationCaptureResult> capture();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorAddressLocationCapture implements AddressLocationCapture {
  const GeolocatorAddressLocationCapture();

  /// A cached fix older than this is not a reliable pin for a new address.
  static const _maxLastKnownAge = Duration(minutes: 2);

  @override
  Future<LocationCaptureResult> capture() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationCaptureResult.failed(
          LocationCaptureFailure.serviceDisabled,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _log('address_location_permission_denied forever=true');
        return const LocationCaptureResult.failed(
          LocationCaptureFailure.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        _log('address_location_permission_denied forever=false');
        return const LocationCaptureResult.failed(
          LocationCaptureFailure.permissionDenied,
        );
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <= _maxLastKnownAge) {
          position = last;
        }
      }
      if (position == null ||
          !isValidCoordinate(position.latitude, position.longitude)) {
        return const LocationCaptureResult.failed(
          LocationCaptureFailure.unavailable,
        );
      }
      _log('address_location_captured');
      return LocationCaptureResult.captured(
        CapturedLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy.isFinite && position.accuracy > 0
              ? position.accuracy
              : null,
          capturedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      return const LocationCaptureResult.failed(
        LocationCaptureFailure.unavailable,
      );
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // Debug builds only; never coordinates.
  void _log(String event) {
    assert(() {
      debugPrint('[Address] $event');
      return true;
    }());
  }
}
