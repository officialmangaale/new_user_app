import 'dart:async';

import 'package:geocoding/geocoding.dart' as geo;

/// A geographic address for a coordinate, as resolved by a reverse geocoder.
///
/// It holds only what a geocoder actually returned. Nothing is invented: every
/// field is either a meaningful value or empty, and display strings are built
/// only from non-empty, de-duplicated parts.
class PlaceAddress {
  const PlaceAddress({
    this.neighborhood = '',
    this.sublocality = '',
    this.locality = '',
    this.district = '',
    this.state = '',
    this.postalCode = '',
    this.street = '',
  });

  final String neighborhood;
  final String sublocality;

  /// The city / town.
  final String locality;
  final String district;
  final String state;
  final String postalCode;
  final String street;

  /// Value for the "Area / locality" field.
  String get area => _firstNonEmpty([neighborhood, sublocality]);

  /// Value for the "City" field. A district stands in for a missing locality.
  String get city => _firstNonEmpty([locality, district]);

  /// Primary header label: neighbourhood, then sub-locality, locality, city,
  /// district.
  String get primaryLabel =>
      _firstNonEmpty([neighborhood, sublocality, locality, city, district]);

  /// Secondary header line: the place's wider context, without repeating the
  /// primary label.
  String get secondaryLabel {
    final primary = primaryLabel.toLowerCase();
    final parts = uniqueParts([
      locality,
      district,
      state,
    ]).where((part) => part.toLowerCase() != primary).toList();
    return parts.join(', ');
  }

  /// One readable line: area, city, district, state, pincode - each once.
  String get formatted => uniqueParts([
    area,
    locality,
    district,
    state,
    postalCode,
  ]).join(', ');

  /// False when the geocoder returned nothing worth showing.
  bool get isMeaningful => primaryLabel.isNotEmpty || postalCode.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'neighborhood': neighborhood,
    'sublocality': sublocality,
    'locality': locality,
    'district': district,
    'state': state,
    'postal_code': postalCode,
    'street': street,
  };

  factory PlaceAddress.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String?)?.trim() ?? '';
    return PlaceAddress(
      neighborhood: text('neighborhood'),
      sublocality: text('sublocality'),
      locality: text('locality'),
      district: text('district'),
      state: text('state'),
      postalCode: text('postal_code'),
      street: text('street'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceAddress &&
      other.neighborhood == neighborhood &&
      other.sublocality == sublocality &&
      other.locality == locality &&
      other.district == district &&
      other.state == state &&
      other.postalCode == postalCode &&
      other.street == street;

  @override
  int get hashCode => Object.hash(
    neighborhood,
    sublocality,
    locality,
    district,
    state,
    postalCode,
    street,
  );
}

/// A geocoder result before cleaning. Plain data so the cleaning rules can be
/// tested without a platform plugin.
class RawPlacemark {
  const RawPlacemark({
    this.name,
    this.street,
    this.thoroughfare,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.administrativeArea,
    this.postalCode,
    this.country,
  });

  final String? name;
  final String? street;
  final String? thoroughfare;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;
}

final _plusCode = RegExp(r'^[0-9A-Z]{4,8}\+[0-9A-Z]{2,}', caseSensitive: false);
final _placeholders = <String>{
  'null',
  'unnamed',
  'unnamed road',
  'unknown',
  'n/a',
  'na',
  'india',
};

/// A geocoder component made safe to show: trimmed, single-spaced, and null
/// when it is empty, a placeholder, or a plus code.
String cleanComponent(String? raw) {
  final text = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return '';
  if (_placeholders.contains(text.toLowerCase())) return '';
  if (_plusCode.hasMatch(text)) return '';
  return text;
}

/// The given parts with blanks removed and repeats (case-insensitive)
/// collapsed, in their original order.
List<String> uniqueParts(Iterable<String> parts) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in parts) {
    final part = cleanComponent(raw);
    if (part.isEmpty || !seen.add(part.toLowerCase())) continue;
    out.add(part);
  }
  return out;
}

String _firstNonEmpty(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final text = cleanComponent(candidate);
    if (text.isNotEmpty) return text;
  }
  return '';
}

final _pincode = RegExp(r'^[1-9]\d{5}$');

/// The best address in [marks], or null when none carries anything meaningful.
PlaceAddress? placeAddressFromPlacemarks(Iterable<RawPlacemark> marks) {
  PlaceAddress? best;
  var bestScore = -1;
  for (final mark in marks) {
    final postal = cleanComponent(mark.postalCode);
    final address = PlaceAddress(
      sublocality: cleanComponent(mark.subLocality),
      locality: cleanComponent(mark.locality),
      district: cleanComponent(mark.subAdministrativeArea),
      state: cleanComponent(mark.administrativeArea),
      postalCode: _pincode.hasMatch(postal) ? postal : '',
      street: _firstNonEmpty([mark.thoroughfare, mark.street]),
    );
    if (!address.isMeaningful) continue;
    final score =
        (address.sublocality.isNotEmpty ? 4 : 0) +
        (address.locality.isNotEmpty ? 3 : 0) +
        (address.postalCode.isNotEmpty ? 2 : 0) +
        (address.state.isNotEmpty ? 1 : 0);
    if (score > bestScore) {
      best = address;
      bestScore = score;
    }
  }
  return best;
}

/// Turns coordinates into a [PlaceAddress].
///
/// Returns null when the geocoder answered but knew nothing useful; throws when
/// it could not answer (offline, no geocoder service). Callers keep the
/// coordinates either way.
abstract interface class ReverseGeocoder {
  Future<PlaceAddress?> reverse(double latitude, double longitude);
}

/// The device's own geocoder (Android `Geocoder`, iOS `CLGeocoder`).
///
/// It needs no API key and does not call Google Maps Platform's Geocoding API,
/// so it works while that API is not enabled for the project.
class PlatformReverseGeocoder implements ReverseGeocoder {
  const PlatformReverseGeocoder({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async {
    final marks = await geo
        .placemarkFromCoordinates(latitude, longitude)
        .timeout(timeout);
    return placeAddressFromPlacemarks(
      marks.map(
        (m) => RawPlacemark(
          name: m.name,
          street: m.street,
          thoroughfare: m.thoroughfare,
          subLocality: m.subLocality,
          locality: m.locality,
          subAdministrativeArea: m.subAdministrativeArea,
          administrativeArea: m.administrativeArea,
          postalCode: m.postalCode,
          country: m.country,
        ),
      ),
    );
  }
}

/// Tries each geocoder in order. A geocoder that throws or finds nothing hands
/// over to the next; the last error is rethrown only if none produced a value.
class CompositeReverseGeocoder implements ReverseGeocoder {
  const CompositeReverseGeocoder(this.geocoders);

  final List<ReverseGeocoder> geocoders;

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async {
    Object? lastError;
    for (final geocoder in geocoders) {
      try {
        final result = await geocoder.reverse(latitude, longitude);
        if (result != null && result.isMeaningful) return result;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }
}
