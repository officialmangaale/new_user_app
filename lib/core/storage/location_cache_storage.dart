import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';
import '../services/reverse_geocoding_service.dart';

/// The last valid device fix, so the app can show a location immediately on the
/// next start instead of waiting for GPS.
class CachedDeviceFix {
  const CachedDeviceFix(this.location, this.at);
  final UserLocation location;
  final DateTime at;
}

/// A reverse-geocoded address and the point it was resolved for.
class CachedGeocode {
  const CachedGeocode(this.location, this.address, this.at);
  final UserLocation location;
  final PlaceAddress address;
  final DateTime at;
}

/// Persistence for the location pipeline. Every read and write is best effort:
/// a storage failure must never block browsing or checkout, so errors are
/// swallowed and reported as "nothing cached".
class LocationCacheStorage {
  const LocationCacheStorage();

  static const _fixKey = 'location.device_fix.v1';
  static const _geocodeKey = 'location.geocode.v1';
  static const _useCurrentKey = 'location.use_current.v1';

  Future<CachedDeviceFix?> readFix() async {
    final map = await _readJson(_fixKey);
    if (map == null) return null;
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final at = DateTime.tryParse('${map['at']}');
    if (lat == null || lng == null || at == null) return null;
    final location = UserLocation(latitude: lat, longitude: lng);
    if (!location.isUsable) return null;
    return CachedDeviceFix(location, at);
  }

  Future<void> writeFix(UserLocation location, DateTime at) {
    if (!location.isUsable) return Future.value();
    return _writeJson(_fixKey, <String, dynamic>{
      'lat': location.latitude,
      'lng': location.longitude,
      'at': at.toUtc().toIso8601String(),
    });
  }

  Future<CachedGeocode?> readGeocode() async {
    final map = await _readJson(_geocodeKey);
    if (map == null) return null;
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final at = DateTime.tryParse('${map['at']}');
    final address = map['address'];
    if (lat == null || lng == null || at == null || address is! Map) {
      return null;
    }
    final location = UserLocation(latitude: lat, longitude: lng);
    final parsed = PlaceAddress.fromJson(Map<String, dynamic>.from(address));
    if (!location.isUsable || !parsed.isMeaningful) return null;
    return CachedGeocode(location, parsed, at);
  }

  Future<void> writeGeocode(
    UserLocation location,
    PlaceAddress address,
    DateTime at,
  ) {
    if (!location.isUsable || !address.isMeaningful) return Future.value();
    return _writeJson(_geocodeKey, <String, dynamic>{
      'lat': location.latitude,
      'lng': location.longitude,
      'at': at.toUtc().toIso8601String(),
      'address': address.toJson(),
    });
  }

  /// Whether the customer explicitly chose "current location" over their saved
  /// address.
  Future<bool> readUseCurrentLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_useCurrentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> writeUseCurrentLocation(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useCurrentKey, value);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeJson(String key, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (_) {}
  }
}
