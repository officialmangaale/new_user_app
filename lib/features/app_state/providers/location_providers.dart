import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

/// Current device location, or null when unavailable.
///
/// Never throws to the UI: discovery and pricing endpoints all accept requests
/// without coordinates, so a denied permission degrades gracefully instead of
/// blocking the app. Read [locationErrorProvider] to surface the reason.
final currentLocationProvider = FutureProvider<UserLocation?>((ref) async {
  try {
    return await ref.watch(locationServiceProvider).current();
  } on LocationException {
    return null;
  }
});

/// The reason location is unavailable, for an inline prompt.
final locationErrorProvider = FutureProvider<String?>((ref) async {
  try {
    await ref.watch(locationServiceProvider).current();
    return null;
  } on LocationException catch (error) {
    return error.message;
  }
});
