import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/google_maps_config.dart';

enum MapCapability { disabled, notConfigured, available, initializationFailed }

final googleMapsConfigProvider = Provider<GoogleMapsConfig>(
  (ref) => GoogleMapsConfig.environment,
);

final mapCapabilityProvider = FutureProvider<MapCapability>((ref) async {
  if (!ref.watch(googleMapsConfigProvider).enabled) {
    return MapCapability.disabled;
  }
  return const NativeMapConfiguration().initialize();
});

final customerMapPickerAvailableProvider = Provider<bool>((ref) {
  final config = ref.watch(googleMapsConfigProvider);
  if (!config.enabled || !config.customerMapPicker) return false;
  return ref
          .watch(mapCapabilityProvider)
          .maybeWhen(data: (state) => state == MapCapability.available, orElse: () => false);
});

final customerPlacesAvailableProvider = Provider<bool>(
  (ref) => ref.watch(googleMapsConfigProvider).customerPlaces,
);

final customerReverseGeocodingAvailableProvider = Provider<bool>(
  (ref) => ref.watch(googleMapsConfigProvider).customerGeocoding,
);

class NativeMapConfiguration {
  const NativeMapConfiguration();
  static const channel = MethodChannel('com.mangaale/maps_configuration');

  Future<MapCapability> initialize() async {
    try {
      final available = await channel
          .invokeMethod<bool>('initialize', {'enabled': true})
          .timeout(const Duration(seconds: 3));
      return available == true
          ? MapCapability.available
          : MapCapability.notConfigured;
    } on MissingPluginException {
      return MapCapability.notConfigured;
    } catch (_) {
      return MapCapability.initializationFailed;
    }
  }
}
