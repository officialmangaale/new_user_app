/// Rules for the Add / Edit address form, as pure functions so they can be
/// tested without widgets, GPS or the network.
library;

import 'dart:async';

import '../../../core/services/api_exception.dart';

/// Copy shown to the customer. Kept here so tests assert the real wording.
abstract final class AddressCopy {
  static const labelRequired = 'Please enter an address label.';
  static const houseRequired =
      'Please enter your house, flat or street details.';
  static const areaRequired = 'Please enter your area or locality.';
  static const pincodeInvalid = 'Please enter a valid 6-digit pincode.';
  static const locationDenied =
      'Location permission is off. You can still enter your address manually.';
  static const locationDeniedForever =
      'Location permission is blocked. Allow it in Settings, or enter your address manually.';
  static const gpsOff = 'Turn on device location to use current location.';
  static const locationUnavailable =
      'Could not get your location. Try again, or enter your address manually.';
  static const pincodeLookupFailed =
      'Could not fetch pincode details. You can continue manually.';
  static const pincodeNotFound =
      'We could not find this pincode. Check it, or continue manually.';
  static const saveTimeout =
      'Saving is taking longer than expected. Please try again.';
  static const saveOffline =
      'No internet connection. Check your connection and try again.';
  static const authExpired = 'Please log in again to save your address.';
  static const saveFailed =
      'We could not save your address right now. Please try again.';
  static const locationInvalid =
      'The pinned location looks wrong. Refresh it or remove it, then save.';
}

/// Fields the form shows errors against.
enum AddressField { label, house, area, pincode, location, general }

String? validateLabel(String value) =>
    value.trim().isEmpty ? AddressCopy.labelRequired : null;

String? validateHouse(String value) =>
    value.trim().isEmpty ? AddressCopy.houseRequired : null;

String? validateArea(String value) =>
    value.trim().isEmpty ? AddressCopy.areaRequired : null;

final _sixDigits = RegExp(r'^\d{6}$');

/// Required, exactly six digits. Indian PIN codes never start with 0.
String? validatePincode(String value) {
  final pin = value.trim();
  if (!_sixDigits.hasMatch(pin) || pin.startsWith('0')) {
    return AddressCopy.pincodeInvalid;
  }
  return null;
}

bool isCompletePincode(String value) => validatePincode(value) == null;

/// The backend stores one `address_line1`. House and street are joined for
/// it; an edit shows the saved line in the house field.
String composeAddressLine1({required String house, required String street}) {
  return [
    house.trim(),
    street.trim(),
  ].where((part) => part.isNotEmpty).join(', ');
}

/// Coordinates are sent only as a valid pair.
bool isValidCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (latitude.isNaN || longitude.isNaN) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  // (0, 0) is a device reporting "no fix", not a delivery location.
  return !(latitude == 0 && longitude == 0);
}

/// A save failure, already translated into what the customer should see.
class AddressSaveError {
  const AddressSaveError(this.message, {this.field = AddressField.general});

  final String message;
  final AddressField field;
}

/// Maps any failure from a save into safe, specific copy. Nothing is
/// swallowed: every error type produces a message.
AddressSaveError describeSaveError(Object error) {
  if (error is TimeoutException) {
    return const AddressSaveError(AddressCopy.saveTimeout);
  }
  if (error is! ApiException) {
    return const AddressSaveError(AddressCopy.saveFailed);
  }
  if (error.isAuthError) {
    return const AddressSaveError(AddressCopy.authExpired);
  }
  if (error.isNetworkError) {
    return AddressSaveError(
      error.message.toLowerCase().contains('timed out')
          ? AddressCopy.saveTimeout
          : AddressCopy.saveOffline,
    );
  }
  if (error.statusCode == 400 || error.statusCode == 422) {
    // user-service names the field in `error.details`.
    final fields = error.errors?.keys.toSet() ?? const <String>{};
    final message = error.message.toLowerCase();
    if (fields.contains('pincode') || message.contains('pincode')) {
      return const AddressSaveError(
        AddressCopy.pincodeInvalid,
        field: AddressField.pincode,
      );
    }
    if (fields.contains('address_line1') || message.contains('address_line1')) {
      return const AddressSaveError(
        AddressCopy.houseRequired,
        field: AddressField.house,
      );
    }
    if (fields.contains('latitude') ||
        fields.contains('longitude') ||
        message.contains('latitude') ||
        message.contains('longitude')) {
      return const AddressSaveError(
        AddressCopy.locationInvalid,
        field: AddressField.location,
      );
    }
    // Any other validation message from the server is safe to show as-is.
    if (error.message.trim().isNotEmpty) {
      return AddressSaveError(error.message.trim());
    }
  }
  return const AddressSaveError(AddressCopy.saveFailed);
}

/// City and state the pincode lookup may fill in.
///
/// A field is filled only if the customer has not typed their own value:
/// it is empty, or still holds what the previous lookup filled. Typed values
/// are never overwritten.
class PincodeAutofill {
  const PincodeAutofill({this.city, this.state});

  final String? city;
  final String? state;
}

PincodeAutofill planPincodeAutofill({
  required String currentCity,
  required String currentState,
  required String? lastAutoCity,
  required String? lastAutoState,
  required String suggestedCity,
  required String suggestedState,
}) {
  bool mayFill(String current, String? lastAuto) =>
      current.trim().isEmpty || current.trim() == (lastAuto ?? '').trim();

  return PincodeAutofill(
    city: suggestedCity.isNotEmpty && mayFill(currentCity, lastAutoCity)
        ? suggestedCity
        : null,
    state: suggestedState.isNotEmpty && mayFill(currentState, lastAutoState)
        ? suggestedState
        : null,
  );
}
