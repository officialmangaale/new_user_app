import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/core/services/reverse_geocoding_service.dart';
import 'package:turquoise_delivery/core/storage/location_cache_storage.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';

class _Gps extends LocationService {
  _Gps(this.result, {this.failure});

  final UserLocation? result;
  final LocationException? failure;
  int calls = 0;
  final prompts = <bool>[];

  @override
  Future<UserLocation> current({bool prompt = true}) async {
    calls++;
    prompts.add(prompt);
    if (failure != null) throw failure!;
    return result!;
  }
}

class _Geocoder implements ReverseGeocoder {
  _Geocoder(this.address);
  final PlaceAddress? address;
  int calls = 0;

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async {
    calls++;
    return address;
  }
}

const _bijnor = UserLocation(latitude: 29.3724, longitude: 78.1358);
const _address = PlaceAddress(
  sublocality: 'Vijay Nagar',
  locality: 'Bijnor',
  state: 'Uttar Pradesh',
  postalCode: '246722',
);

String _fixJson(UserLocation location, DateTime at) => jsonEncode({
  'lat': location.latitude,
  'lng': location.longitude,
  'at': at.toUtc().toIso8601String(),
});

ProviderContainer _container({
  required _Gps gps,
  _Geocoder? geocoder,
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      locationServiceProvider.overrideWithValue(gps),
      reverseGeocoderProvider.overrideWithValue(
        geocoder ?? _Geocoder(_address),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationCacheStorage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a fix survives a round trip', () async {
      const storage = LocationCacheStorage();
      final at = DateTime.utc(2026, 10, 15, 9);
      await storage.writeFix(_bijnor, at);

      final read = await storage.readFix();
      expect(read!.location, _bijnor);
      expect(read.at, at);
    });

    test('an unusable fix is never stored', () async {
      const storage = LocationCacheStorage();
      await storage.writeFix(
        const UserLocation(latitude: 0, longitude: 0),
        DateTime.now(),
      );
      expect(await storage.readFix(), isNull);
    });

    test('corrupt data reads as nothing, not an exception', () async {
      SharedPreferences.setMockInitialValues({
        'location.device_fix.v1': '{not json',
        'location.geocode.v1': '[1,2,3]',
      });
      const storage = LocationCacheStorage();
      expect(await storage.readFix(), isNull);
      expect(await storage.readGeocode(), isNull);
    });

    test('a geocode round-trips with its point', () async {
      const storage = LocationCacheStorage();
      await storage.writeGeocode(_bijnor, _address, DateTime.now());
      final read = await storage.readGeocode();
      expect(read!.address, _address);
      expect(read.location, _bijnor);
    });
  });

  group('device fix controller', () {
    test('a fresh cached fix is used without asking GPS', () async {
      SharedPreferences.setMockInitialValues({
        'location.device_fix.v1': _fixJson(
          _bijnor,
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });
      final gps = _Gps(const UserLocation(latitude: 1, longitude: 1));
      final container = _container(gps: gps);

      expect(await container.read(currentLocationProvider.future), _bijnor);
      expect(gps.calls, 0, reason: 'restart shows the last location at once');
    });

    test('an older cached fix is shown, then refreshed quietly (no prompt)',
        () async {
      const moved = UserLocation(latitude: 28.5355, longitude: 77.3910);
      SharedPreferences.setMockInitialValues({
        'location.device_fix.v1': _fixJson(
          _bijnor,
          DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      });
      final gps = _Gps(moved);
      final container = _container(gps: gps);
      container.listen(currentLocationProvider, (_, _) {});

      expect(await container.read(currentLocationProvider.future), _bijnor);
      // Let the quiet refresh run.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gps.calls, 1);
      expect(gps.prompts.single, isFalse, reason: 'never interrupts with a dialog');
      expect(await container.read(currentLocationProvider.future), moved);
    });

    test('a cache older than 12 hours is not trusted', () async {
      SharedPreferences.setMockInitialValues({
        'location.device_fix.v1': _fixJson(
          const UserLocation(latitude: 12.97, longitude: 77.59),
          DateTime.now().subtract(const Duration(hours: 13)),
        ),
      });
      final gps = _Gps(_bijnor);
      final container = _container(gps: gps);

      expect(await container.read(currentLocationProvider.future), _bijnor);
      expect(gps.calls, 1);
      expect(gps.prompts.single, isTrue);
    });

    test('a failed fix keeps the previous location and reports why', () async {
      SharedPreferences.setMockInitialValues({
        'location.device_fix.v1': _fixJson(
          _bijnor,
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });
      final gps = _Gps(
        null,
        failure: const LocationException(
          LocationFailure.serviceDisabled,
          'Location services are turned off.',
        ),
      );
      final container = _container(gps: gps);
      await container.read(currentLocationProvider.future);

      final refreshed = await container
          .read(deviceFixProvider.notifier)
          .refresh();

      expect(refreshed, _bijnor, reason: 'the last valid fix is kept');
      final status = container.read(deviceFixStatusProvider);
      expect(status.failure, LocationFailure.serviceDisabled);
      expect(container.read(locationErrorProvider), isNull);
    });

    test('a jittery new fix does not move the location', () async {
      SharedPreferences.setMockInitialValues({
        'location.device_fix.v1': _fixJson(
          _bijnor,
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });
      // About 4 m away.
      final gps = _Gps(
        const UserLocation(latitude: 29.37243, longitude: 78.13583),
      );
      final container = _container(gps: gps);
      await container.read(currentLocationProvider.future);

      final refreshed = await container
          .read(deviceFixProvider.notifier)
          .refresh();

      expect(refreshed, _bijnor, reason: 'no refetch of restaurants for a wobble');
    });
  });

  group('geocode cache and choice', () {
    test('a cached address for the same spot is not geocoded again', () async {
      SharedPreferences.setMockInitialValues({});
      const storage = LocationCacheStorage();
      await storage.writeFix(_bijnor, DateTime.now());
      await storage.writeGeocode(_bijnor, _address, DateTime.now());
      final geocoder = _Geocoder(_address);
      final container = _container(
        gps: _Gps(_bijnor),
        geocoder: geocoder,
      );

      final result = await container.read(deviceAddressProvider.future);

      expect(result.status, DeviceAddressStatus.resolved);
      expect(result.address, _address);
      expect(geocoder.calls, 0);
    });

    test('a geocode is made once per spot and then cached', () async {
      SharedPreferences.setMockInitialValues({});
      final geocoder = _Geocoder(_address);
      final container = _container(gps: _Gps(_bijnor), geocoder: geocoder);

      await container.read(deviceAddressProvider.future);
      container.invalidate(deviceAddressProvider);
      await container.read(deviceAddressProvider.future);

      expect(geocoder.calls, 1, reason: 'second lookup came from the cache');
    });

    test('the use-current-location choice survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = _container(gps: _Gps(_bijnor));
      first.read(useCurrentLocationProvider);
      first.read(useCurrentLocationProvider.notifier).choose(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final second = _container(gps: _Gps(_bijnor));
      second.listen(useCurrentLocationProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(second.read(useCurrentLocationProvider), isTrue);
    });
  });
}
