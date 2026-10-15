import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_exception.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/reverse_geocoding_service.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../app_state/providers/app_controller.dart';
import '../../app_state/providers/location_providers.dart';
import '../../orders/providers/orders_providers.dart';

/// Where a delivery location came from.
enum DeliveryLocationSource { currentLocation, savedAddress, manualMap }

/// The one delivery location discovery, serviceability, pricing and checkout
/// all use.
///
/// It answers WHERE the customer is (coordinates plus the geographic address).
/// How the rider finds the door - house, flat, floor, receiver - belongs to a
/// saved address and is not needed to browse or to price a delivery.
///
/// What the customer sees (label, address text) and what pricing sends
/// (latitude, longitude) live in the same object, so they cannot drift apart:
/// a "Home" label can never travel with another place's coordinates.
class DeliveryLocation {
  const DeliveryLocation({
    required this.id,
    required this.label,
    required this.formattedAddress,
    required this.locality,
    required this.city,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.state = '',
    this.district = '',
  });

  final String id;
  final String label;
  final String formattedAddress;
  final String locality;
  final String city;
  final String state;
  final String district;
  final String postalCode;
  final double latitude;
  final double longitude;
  final DeliveryLocationSource source;

  /// True when the customer has a saved address (with door details) here.
  bool get hasSavedDetails => source == DeliveryLocationSource.savedAddress;

  UserLocation get point =>
      UserLocation(latitude: latitude, longitude: longitude);

  factory DeliveryLocation.fromAddress(CustomerAddress address) {
    assert(address.hasPin, 'A delivery location needs a usable pin.');
    return DeliveryLocation(
      id: address.id,
      label: address.label,
      formattedAddress: address.singleLine,
      locality: address.area,
      city: address.city,
      state: address.state,
      district: address.district,
      postalCode: address.pincode,
      latitude: address.latitude!,
      longitude: address.longitude!,
      source: DeliveryLocationSource.savedAddress,
    );
  }

  /// The device position, with the geocoded address when one was resolved.
  /// Text is filled only from what the geocoder returned.
  factory DeliveryLocation.fromDevice(
    UserLocation location, {
    PlaceAddress? address,
  }) {
    return DeliveryLocation(
      id: '',
      label: 'Current location',
      formattedAddress: address?.formatted ?? '',
      locality: address?.area ?? '',
      city: address?.city ?? '',
      state: address?.state ?? '',
      district: address?.district ?? '',
      postalCode: address?.postalCode ?? '',
      latitude: location.latitude,
      longitude: location.longitude,
      source: DeliveryLocationSource.currentLocation,
    );
  }
}

/// Outcome of choosing the delivery location.
sealed class DeliveryLocationState {
  const DeliveryLocationState();
}

/// A location with a usable pin: pricing may proceed.
final class DeliveryLocationResolved extends DeliveryLocationState {
  const DeliveryLocationResolved(this.location);
  final DeliveryLocation location;
}

/// A saved address exists but has no usable pin. Its text is never priced and
/// the device GPS is never silently substituted for it - not for pricing, and
/// not for discovery, so the header, the distances and the bill cannot describe
/// different places. The customer confirms a location (or chooses current
/// location) explicitly.
final class DeliveryLocationNeedsConfirmation extends DeliveryLocationState {
  const DeliveryLocationNeedsConfirmation(this.address);
  final CustomerAddress address;
}

/// No usable saved address and no device location.
final class DeliveryLocationUnavailable extends DeliveryLocationState {
  const DeliveryLocationUnavailable();
}

/// Thrown by the bill when there is no priceable delivery location, so the
/// cart can offer the right fix without calling the pricing API.
class DeliveryLocationRequired implements Exception {
  const DeliveryLocationRequired(this.address);

  /// The saved address that needs confirming, or null when there is none.
  final CustomerAddress? address;

  String get message => address == null
      ? 'Choose a delivery location to see delivery charges.'
      : 'Please confirm your delivery location.';

  @override
  String toString() => message;
}

/// Pure selection rule, so it can be tested without providers.
///
/// - When the customer chose "current location" and the device position is
///   usable, that is the delivery location, whatever is saved.
/// - Otherwise a default (else first) saved address wins. With a usable pin it
///   is priced from that pin; without one it needs confirmation.
/// - With no saved address the device location is used: a customer can browse
///   and be priced before ever saving an address.
DeliveryLocationState chooseDeliveryLocation({
  required List<CustomerAddress> addresses,
  required UserLocation? device,
  bool useCurrentLocation = false,
  PlaceAddress? deviceAddress,
}) {
  final usableDevice = device != null && device.isUsable ? device : null;
  if (useCurrentLocation && usableDevice != null) {
    return DeliveryLocationResolved(
      DeliveryLocation.fromDevice(usableDevice, address: deviceAddress),
    );
  }
  final address =
      addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
  if (address != null) {
    return address.hasPin
        ? DeliveryLocationResolved(DeliveryLocation.fromAddress(address))
        : DeliveryLocationNeedsConfirmation(address);
  }
  if (usableDevice != null) {
    return DeliveryLocationResolved(
      DeliveryLocation.fromDevice(usableDevice, address: deviceAddress),
    );
  }
  return const DeliveryLocationUnavailable();
}

/// The canonical selected delivery location. Re-evaluates when the address
/// book, the signed-in state, the "use current location" choice or the device
/// position changes, so pricing and discovery follow a change immediately.
final deliveryLocationProvider = FutureProvider<DeliveryLocationState>((
  ref,
) async {
  final authenticated = ref.watch(
    appControllerProvider.select((s) => s.authenticated),
  );
  final useCurrent = ref.watch(useCurrentLocationProvider);
  // Register dependencies before any async gap.
  final addressesFuture = authenticated
      ? ref.watch(addressesProvider.future)
      : null;
  final List<CustomerAddress> addresses;
  try {
    addresses = addressesFuture == null
        ? const <CustomerAddress>[]
        : await addressesFuture;
  } on ApiException catch (error) {
    if (error.isAuthError) {
      throw StateError(
        'Your session has expired. Please login again to continue checkout.',
      );
    }
    rethrow;
  }
  // The device is consulted only when it can matter: the customer chose it,
  // or there is no saved address at all. A customer with a saved address (even
  // one still to be confirmed) never triggers GPS or its permission prompt.
  final saved =
      addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
  final needsDevice = useCurrent || saved == null;
  final device = needsDevice
      ? await ref.watch(currentLocationProvider.future)
      : null;
  return chooseDeliveryLocation(
    addresses: addresses,
    device: device,
    useCurrentLocation: useCurrent,
  );
});

/// The coordinates restaurant discovery, distances and nearby grocery use.
///
/// Always the canonical selection - never the raw device position when a
/// different location is selected - so the Home header, the list distances and
/// the cart can never describe different places. Null means "no location":
/// callers show no distance rather than a made-up one.
final discoveryCoordinatesProvider = FutureProvider<UserLocation?>((ref) async {
  final pending = ref.watch(deliveryLocationProvider.future);
  final DeliveryLocationState state;
  try {
    state = await pending;
  } catch (_) {
    // An expired session or a failed address fetch must not blank discovery:
    // browsing needs only a position.
    return ref.watch(currentLocationProvider.future);
  }
  return switch (state) {
    DeliveryLocationResolved(:final location) => location.point,
    DeliveryLocationNeedsConfirmation() => null,
    DeliveryLocationUnavailable() => null,
  };
});

/// Where the screen is in resolving a location.
enum DeliveryLocationPhase {
  /// Working out where the customer is.
  locating,

  /// A location with coordinates is selected.
  ready,

  /// A saved address exists but its location must be confirmed first.
  needsConfirmation,

  /// No location could be determined and none is saved.
  unavailable,
}

/// Everything a screen needs to describe the selected delivery location,
/// derived from the canonical state and never maintained separately.
class DeliveryLocationView {
  const DeliveryLocationView({
    required this.phase,
    required this.primary,
    required this.secondary,
    this.location,
    this.address,
    this.placeAddress,
    this.addressPending = false,
    this.addressFailed = false,
    this.deviceMessage,
  });

  final DeliveryLocationPhase phase;

  /// Header title, e.g. "Vijay Nagar" or "Home".
  final String primary;

  /// Header subtitle, e.g. "Bijnor, Uttar Pradesh". May be empty.
  final String secondary;

  /// The selected location when [phase] is [DeliveryLocationPhase.ready].
  final DeliveryLocation? location;

  /// The saved address involved: the selected one, or the one that needs
  /// confirmation.
  final CustomerAddress? address;

  /// The geocoded address of the device fix when it is the selection.
  final PlaceAddress? placeAddress;

  /// Coordinates are known but their address is still being looked up.
  final bool addressPending;

  /// Coordinates are known but no address could be found for them.
  final bool addressFailed;

  /// Why the device location is unavailable, when it is.
  final String? deviceMessage;

  bool get isCurrentLocation =>
      location?.source == DeliveryLocationSource.currentLocation;

  /// A location with coordinates but without a saved address's door details.
  bool get needsDoorDetails => isCurrentLocation;
}

/// Pure projection used by [deliveryLocationViewProvider].
DeliveryLocationView describeDeliveryLocation({
  required AsyncValue<DeliveryLocationState> selection,
  required AsyncValue<DeviceAddressResult> deviceAddress,
  required String? deviceMessage,
}) {
  if (selection.isLoading && !selection.hasValue) {
    return const DeliveryLocationView(
      phase: DeliveryLocationPhase.locating,
      primary: 'Locating…',
      secondary: '',
    );
  }
  if (selection.hasError && !selection.hasValue) {
    return DeliveryLocationView(
      phase: DeliveryLocationPhase.unavailable,
      primary: 'Select location',
      secondary: '',
      deviceMessage: deviceMessage,
    );
  }
  final state = selection.requireValue;
  switch (state) {
    case DeliveryLocationUnavailable():
      return DeliveryLocationView(
        phase: DeliveryLocationPhase.unavailable,
        primary: 'Select location',
        secondary: deviceMessage == null ? '' : 'Unable to determine location',
        deviceMessage: deviceMessage,
      );
    case DeliveryLocationNeedsConfirmation(:final address):
      return DeliveryLocationView(
        phase: DeliveryLocationPhase.needsConfirmation,
        primary: _savedPrimary(address),
        secondary: 'Confirm location',
        address: address,
      );
    case DeliveryLocationResolved(:final location):
      if (location.source == DeliveryLocationSource.savedAddress) {
        return DeliveryLocationView(
          phase: DeliveryLocationPhase.ready,
          primary: _savedPrimaryFromLocation(location),
          secondary: location.formattedAddress,
          location: location,
        );
      }
      final result = deviceAddress.value;
      final resolved = result?.status == DeviceAddressStatus.resolved
          ? result!.address
          : null;
      final enriched = resolved == null
          ? location
          : DeliveryLocation.fromDevice(location.point, address: resolved);
      if (resolved != null) {
        return DeliveryLocationView(
          phase: DeliveryLocationPhase.ready,
          primary: resolved.primaryLabel.isNotEmpty
              ? resolved.primaryLabel
              : 'Current location',
          secondary: resolved.secondaryLabel,
          location: enriched,
          placeAddress: resolved,
        );
      }
      final failed = result?.status == DeviceAddressStatus.failed;
      return DeliveryLocationView(
        phase: DeliveryLocationPhase.ready,
        // Never an invented place name: the coordinates are real, the label is
        // honestly generic until a geocoder answers.
        primary: failed ? 'Current location' : 'Finding your area…',
        secondary: '',
        location: enriched,
        addressPending: !failed,
        addressFailed: failed,
      );
  }
}

String _savedPrimary(CustomerAddress address) {
  final label = address.label.trim();
  final area = address.area.trim();
  if (label.isNotEmpty && area.isNotEmpty) return '$label · $area';
  if (label.isNotEmpty) return label;
  if (area.isNotEmpty) return area;
  return address.singleLine.isNotEmpty ? address.singleLine : 'Saved address';
}

String _savedPrimaryFromLocation(DeliveryLocation location) {
  final label = location.label.trim();
  final area = location.locality.trim();
  if (label.isNotEmpty && area.isNotEmpty) return '$label · $area';
  if (label.isNotEmpty) return label;
  if (area.isNotEmpty) return area;
  return location.formattedAddress.isNotEmpty
      ? location.formattedAddress
      : 'Saved address';
}

/// The selected delivery location, described for display.
///
/// Header, cart address card and the location sheet all read this one view.
final deliveryLocationViewProvider = Provider<DeliveryLocationView>((ref) {
  final selection = ref.watch(deliveryLocationProvider);
  final state = selection.value;
  // The device pipeline is observed only when the selection depends on it, so
  // a customer with a pinned saved address never triggers GPS or geocoding by
  // merely looking at the header.
  final usesDevice =
      state is DeliveryLocationResolved &&
      state.location.source == DeliveryLocationSource.currentLocation;
  final deviceAddress = usesDevice
      ? ref.watch(deviceAddressProvider)
      : const AsyncData<DeviceAddressResult>(DeviceAddressResult.noFix);
  final deviceMessage = state is DeliveryLocationUnavailable
      ? ref.watch(locationErrorProvider)
      : null;
  return describeDeliveryLocation(
    selection: selection,
    deviceAddress: deviceAddress,
    deviceMessage: deviceMessage,
  );
});
