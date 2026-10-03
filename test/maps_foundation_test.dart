import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/config/google_maps_config.dart';
import 'package:turquoise_delivery/core/maps/map_capabilities.dart';
import 'package:turquoise_delivery/features/account/address/address_map_selection.dart';

class FakeGeocoder implements AddressReverseGeocoder {
  final calls = <Completer<String?>>[];
  @override
  Future<String?> reverse(double latitude, double longitude) {
    final completer = Completer<String?>();
    calls.add(completer);
    return completer.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('disabled map never touches native SDK', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeMapConfiguration.channel, (_) async {
          calls++;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeMapConfiguration.channel, null),
    );
    final container = ProviderContainer(
      overrides: [
        googleMapsConfigProvider.overrideWithValue(const GoogleMapsConfig()),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(mapCapabilityProvider.future),
      MapCapability.disabled,
    );
    expect(calls, 0);
    expect(container.read(customerMapPickerAvailableProvider), false);
  });
  for (final nativeReady in [false, true]) {
    test(
      'customer tracking capability follows native readiness $nativeReady',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              NativeMapConfiguration.channel,
              (_) async => nativeReady,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(NativeMapConfiguration.channel, null),
        );
        final container = ProviderContainer(
          overrides: [
            googleMapsConfigProvider.overrideWithValue(
              const GoogleMapsConfig(enabled: true),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(mapCapabilityProvider.future),
          nativeReady ? MapCapability.available : MapCapability.notConfigured,
        );
      },
    );
  }
  test('missing native plugin is a safe fallback', () async {
    expect(
      await const NativeMapConfiguration().initialize(),
      MapCapability.notConfigured,
    );
  });
  test(
    'picker validates coordinates and remains usable without geocoding',
    () async {
      final controller = AddressMapSelectionController();
      addTearDown(controller.dispose);
      expect(await controller.select(0, 0), false);
      expect(await controller.select(double.nan, 1), false);
      expect(await controller.select(91, 1), false);
      expect(await controller.select(28.61, 77.2), true);
      expect(controller.selection!.latitude, 28.61);
      expect(controller.selection!.address, isNull);
      expect(controller.resolving, false);
    },
  );
  test(
    'late geocode cannot overwrite a newer pin or notify after disposal',
    () async {
      final fake = FakeGeocoder();
      final controller = AddressMapSelectionController(geocoder: fake);
      final first = controller.select(28.61, 77.2);
      final second = controller.select(28.62, 77.3);
      fake.calls[1].complete('New address');
      await second;
      fake.calls[0].complete('Old address');
      await first;
      expect(controller.selection!.address, 'New address');
      final third = controller.select(28.63, 77.4);
      controller.dispose();
      fake.calls[2].complete('Disposed');
      expect(await third, false);
    },
  );
  test('geocoding failure preserves manual coordinate selection', () async {
    final fake = FakeGeocoder();
    final controller = AddressMapSelectionController(geocoder: fake);
    addTearDown(controller.dispose);
    final pending = controller.select(28.61, 77.2);
    fake.calls.single.completeError(StateError('offline'));
    expect(await pending, true);
    expect(controller.selection!.address, isNull);
    expect(controller.resolving, false);
  });
}
