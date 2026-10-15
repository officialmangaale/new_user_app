import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/maps/map_capabilities.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../../../core/storage/location_cache_storage.dart';
import '../../orders/providers/orders_providers.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

final locationCacheStorageProvider = Provider<LocationCacheStorage>(
  (ref) => const LocationCacheStorage(),
);

/// Server-side reverse geocoding (user-service). Used only when the Geocoding
/// API has been enabled for the project and the build says so; otherwise the
/// device geocoder is the whole story.
class _ServerReverseGeocoder implements ReverseGeocoder {
  const _ServerReverseGeocoder(this._ref);
  final Ref _ref;

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async {
    final resolved = await _ref
        .read(accountRepositoryProvider)
        .reverseGeocodeAddress(latitude: latitude, longitude: longitude);
    return PlaceAddress(
      sublocality: resolved.area,
      locality: resolved.city,
      district: resolved.district,
      state: resolved.state,
      postalCode: resolved.pincode,
    );
  }
}

final reverseGeocoderProvider = Provider<ReverseGeocoder>((ref) {
  final serverEnabled = ref.watch(customerReverseGeocodingAvailableProvider);
  return CompositeReverseGeocoder([
    if (serverEnabled) _ServerReverseGeocoder(ref),
    const PlatformReverseGeocoder(),
  ]);
});

/// Progress and outcome of the most recent GPS attempt, for the UI.
///
/// Kept apart from the fix itself so that a status change ("locating", "denied")
/// never looks like a new position and never refetches restaurants.
class DeviceFixStatus {
  const DeviceFixStatus({
    this.locating = false,
    this.failure,
    this.failureMessage,
  });

  final bool locating;

  /// Why the most recent attempt failed. A failure never clears the last fix.
  final LocationFailure? failure;
  final String? failureMessage;
}

class DeviceFixStatusController extends Notifier<DeviceFixStatus> {
  @override
  DeviceFixStatus build() => const DeviceFixStatus();

  void set(DeviceFixStatus status) => state = status;
}

final deviceFixStatusProvider =
    NotifierProvider<DeviceFixStatusController, DeviceFixStatus>(
      DeviceFixStatusController.new,
    );

/// Owns the device position for the whole app.
///
/// One instance, so GPS is requested once per need - not once per widget build
/// or per provider that wants coordinates. The value is the last valid fix (or
/// null). It is persisted: a restart shows a location immediately and refreshes
/// quietly behind it.
class DeviceFixController extends AsyncNotifier<UserLocation?> {
  /// A cached fix older than this is not shown as the current position.
  static const maxCacheAge = Duration(hours: 12);

  /// Older than this and a quiet refresh is started behind the cached fix.
  static const refreshAfter = Duration(minutes: 5);

  /// A new fix this close to the current one is jitter, not movement; keeping
  /// the old coordinates avoids refetching restaurants for a 5 m wobble.
  static const jitterMeters = 30.0;

  Future<UserLocation?>? _inFlight;

  @override
  Future<UserLocation?> build() async {
    final storage = ref.read(locationCacheStorageProvider);
    final cached = await storage.readFix();
    if (cached != null) {
      final age = DateTime.now().difference(cached.at);
      if (age <= maxCacheAge) {
        if (age > refreshAfter) {
          // Behind the cached fix: no prompt, no spinner, and the value only
          // changes if the customer actually moved.
          scheduleMicrotask(() => unawaited(_refreshQuietly()));
        }
        return cached.location;
      }
    }
    return _locate(prompt: true);
  }

  /// Fetches a fresh position now (a customer-initiated refresh).
  Future<UserLocation?> refresh() async {
    // A quiet background refresh may be running; it cannot show the permission
    // dialog, so let it finish and then ask properly.
    final pending = _inFlight;
    if (pending != null) await pending;
    final fix = await _locate(prompt: true);
    return _adopt(fix);
  }

  Future<void> _refreshQuietly() async {
    final fix = await _locate(prompt: false);
    _adopt(fix);
  }

  /// Publishes [fix] only when it is a different place, so dependants are not
  /// rebuilt for an unchanged position.
  UserLocation? _adopt(UserLocation? fix) {
    final current = state.value;
    if (fix != null && fix != current) {
      state = AsyncData<UserLocation?>(fix);
    }
    return fix ?? current;
  }

  Future<UserLocation?> _locate({required bool prompt}) {
    return _inFlight ??= _doLocate(prompt).whenComplete(() => _inFlight = null);
  }

  Future<UserLocation?> _doLocate(bool prompt) async {
    final status = ref.read(deviceFixStatusProvider.notifier);
    status.set(const DeviceFixStatus(locating: true));
    try {
      final located = await ref
          .read(locationServiceProvider)
          .current(prompt: prompt);
      if (!located.isUsable) {
        throw const LocationException(
          LocationFailure.unavailable,
          'Unable to determine your location. Please try again.',
        );
      }
      final previous = state.value;
      final keep = previous != null && previous.metersTo(located) < jitterMeters
          ? previous
          : located;
      unawaited(
        ref.read(locationCacheStorageProvider).writeFix(keep, DateTime.now()),
      );
      status.set(const DeviceFixStatus());
      return keep;
    } on LocationException catch (error) {
      status.set(
        DeviceFixStatus(failure: error.failure, failureMessage: error.message),
      );
      return null;
    } catch (_) {
      status.set(
        const DeviceFixStatus(
          failure: LocationFailure.unavailable,
          failureMessage: 'Unable to determine your location. Please try again.',
        ),
      );
      return null;
    }
  }
}

final deviceFixProvider =
    AsyncNotifierProvider<DeviceFixController, UserLocation?>(
      DeviceFixController.new,
    );

/// Current device location, or null when unavailable.
///
/// Never throws to the UI: discovery and pricing endpoints all accept requests
/// without coordinates, so a denied permission degrades gracefully instead of
/// blocking the app. Read [locationErrorProvider] to surface the reason.
final currentLocationProvider = FutureProvider<UserLocation?>((ref) {
  return ref.watch(deviceFixProvider.future);
});

/// The reason location is unavailable, for an inline prompt. Reads the state
/// the controller already holds; it never starts a second GPS request.
final locationErrorProvider = Provider<String?>((ref) {
  if (ref.watch(deviceFixProvider).value != null) return null;
  return ref.watch(deviceFixStatusProvider).failureMessage;
});

enum DeviceAddressStatus {
  /// There is no usable fix to resolve.
  noFix,

  /// A geocoder answered with a meaningful address.
  resolved,

  /// The fix is known but no address could be resolved (offline, no geocoder,
  /// or nothing found). Coordinates remain fully usable.
  failed,
}

class DeviceAddressResult {
  const DeviceAddressResult(this.status, [this.address]);

  final DeviceAddressStatus status;
  final PlaceAddress? address;

  static const noFix = DeviceAddressResult(DeviceAddressStatus.noFix);
  static const failed = DeviceAddressResult(DeviceAddressStatus.failed);
}

/// The reverse-geocoded address of the current device fix.
///
/// A cached result for (nearly) the same point is reused, so moving a few
/// metres or restarting the app does not geocode again. A failure is reported
/// as [DeviceAddressStatus.failed] and the coordinates are never discarded;
/// the customer retries from the location sheet (no hidden timer, no polling).
final deviceAddressProvider = FutureProvider<DeviceAddressResult>((ref) async {
  final fix = await ref.watch(currentLocationProvider.future);
  if (fix == null || !fix.isUsable) return DeviceAddressResult.noFix;

  final storage = ref.read(locationCacheStorageProvider);
  final cached = await storage.readGeocode();
  if (cached != null &&
      cached.location.metersTo(fix) < 150 &&
      DateTime.now().difference(cached.at) < const Duration(days: 7)) {
    return DeviceAddressResult(DeviceAddressStatus.resolved, cached.address);
  }

  final geocoder = ref.read(reverseGeocoderProvider);
  try {
    final address = await geocoder.reverse(fix.latitude, fix.longitude);
    if (address != null && address.isMeaningful) {
      unawaited(storage.writeGeocode(fix, address, DateTime.now()));
      return DeviceAddressResult(DeviceAddressStatus.resolved, address);
    }
  } catch (_) {
    // Falls through: the coordinates stay fully usable.
  }
  return DeviceAddressResult.failed;
});

/// Whether the customer explicitly chose "current location" over their saved
/// address. Persisted, so the choice survives a restart.
class UseCurrentLocationChoice extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_hydrate());
    return false;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(locationCacheStorageProvider)
        .readUseCurrentLocation();
    if (stored != state) state = stored;
  }

  void choose(bool useCurrent) {
    if (state == useCurrent) return;
    state = useCurrent;
    unawaited(
      ref.read(locationCacheStorageProvider).writeUseCurrentLocation(useCurrent),
    );
  }
}

final useCurrentLocationProvider =
    NotifierProvider<UseCurrentLocationChoice, bool>(
      UseCurrentLocationChoice.new,
    );
