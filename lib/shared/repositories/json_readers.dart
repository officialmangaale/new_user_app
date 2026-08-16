/// Defensive JSON readers shared by every repository.
///
/// restaurant-service returns different field aliases per endpoint (for example
/// `average_rating` vs `rating`, `total_amount` vs `grand_total`). The
/// production web client handles this the same way in `src/utils/apiAdapters.ts`;
/// these are the Dart equivalents so no repository grows its own copy.
library;

/// Extracts a list from either a bare JSON array or an object wrapping one
/// under any of [keys].
List<Map<String, dynamic>> listFrom(Object? raw, {required List<String> keys}) {
  if (raw is List) return _mapList(raw);
  if (raw is Map) {
    for (final key in keys) {
      final nested = raw[key];
      if (nested is List) return _mapList(nested);
    }
  }
  return const <Map<String, dynamic>>[];
}

/// Reads a nested list from [json] at [key].
List<Map<String, dynamic>> readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is List ? _mapList(value) : const <Map<String, dynamic>>[];
}

/// First non-empty value among [keys], stringified. Empty string when absent.
String readString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

/// First numeric value among [keys]. Tolerates numbers sent as strings
/// (including currency-formatted ones such as "₹120.50"). Returns 0 when absent.
double readDouble(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

/// Integer form of [readDouble].
int readInt(Map<String, dynamic> json, List<String> keys) =>
    readDouble(json, keys).round();

/// True only for an explicit truthy value; absent stays [orElse].
bool readBool(Map<String, dynamic> json, List<String> keys, {bool orElse = false}) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
    }
  }
  return orElse;
}

List<Map<String, dynamic>> _mapList(List<Object?> source) => source
    .whereType<Map>()
    .map((entry) => Map<String, dynamic>.from(entry))
    .toList(growable: false);
