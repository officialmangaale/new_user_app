import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'address_location_capture.dart';
import 'pincode_lookup.dart';

/// Kept alive for the app session so looked-up PIN codes stay cached.
final pincodeLookupProvider = Provider<PincodeLookup>(
  (ref) => PostalPincodeLookup(),
);

final addressLocationCaptureProvider = Provider<AddressLocationCapture>(
  (ref) => const GeolocatorAddressLocationCapture(),
);
