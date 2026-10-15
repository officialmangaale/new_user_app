/// Formats a distance for a restaurant card.
///
/// Returns null when there is no real distance to show (unknown, NaN, or
/// negative): callers then omit the distance entirely instead of printing
/// "0 km". A distance under a kilometre is shown in metres so 40 m reads as
/// "40 m", not "0 km".
String? formatDistanceKm(double? km) {
  if (km == null || km.isNaN || km.isInfinite || km < 0) return null;
  if (km < 1) {
    final meters = km * 1000;
    final rounded = meters < 100
        ? (meters / 10).round() * 10
        : (meters / 50).round() * 50;
    if (rounded >= 1000) return '1 km';
    return '$rounded m';
  }
  final text = km.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} km';
}
