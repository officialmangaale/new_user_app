import 'dart:async';

import 'package:flutter/foundation.dart';

import 'address_form_logic.dart';
import 'address_location_capture.dart';

/// Future picker boundary. Manual/GPS address forms do not depend on it.
abstract interface class AddressReverseGeocoder {
  Future<String?> reverse(double latitude, double longitude);
}

class AddressMapSelection {
  const AddressMapSelection(this.latitude, this.longitude, {this.address});
  final double latitude;
  final double longitude;
  final String? address;
}

class AddressMapSelectionController extends ChangeNotifier {
  AddressMapSelectionController({this.geocoder});
  final AddressReverseGeocoder? geocoder;
  AddressMapSelection? selection;
  bool resolving = false;
  bool _disposed = false;
  int _revision = 0;

  Future<bool> useCapturedLocation(CapturedLocation location) =>
      select(location.latitude, location.longitude);

  Future<bool> select(double latitude, double longitude) async {
    if (_disposed || !isValidCoordinate(latitude, longitude)) return false;
    final revision = ++_revision;
    selection = AddressMapSelection(latitude, longitude);
    resolving = geocoder != null;
    notifyListeners();
    if (geocoder == null) return true;
    String? address;
    try {
      address = await geocoder!
          .reverse(latitude, longitude)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Coordinates remain available for manual address confirmation.
    }
    if (_disposed || revision != _revision) return false;
    selection = AddressMapSelection(latitude, longitude, address: address);
    resolving = false;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
