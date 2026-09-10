/// Geometry for the live-tracking map, kept free of the Google Maps SDK so it
/// can be unit-tested without a device.
library;

/// A point on the map. A plain value type rather than the SDK's LatLng, so
/// nothing here depends on the plugin.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// The rectangle the camera should frame.
class GeoBounds {
  const GeoBounds({required this.southwest, required this.northeast});

  final GeoPoint southwest;
  final GeoPoint northeast;
}

/// Smallest span, in degrees, the camera is allowed to frame.
///
/// Framing a single point — or a rider standing at the restaurant — would
/// otherwise zoom to street level and show nothing useful. About 0.004° is
/// roughly 450 m at Indian latitudes.
const double minimumSpanDegrees = 0.004;

/// Bounds that frame every known point, or null when there are none.
///
/// Padded to [minimumSpanDegrees] so a lone point, or two points on top of
/// each other, still produce a sensible neighbourhood view instead of an
/// extreme zoom.
GeoBounds? boundsFor(Iterable<GeoPoint> points) {
  final list = points.toList(growable: false);
  if (list.isEmpty) return null;

  var south = list.first.latitude;
  var north = list.first.latitude;
  var west = list.first.longitude;
  var east = list.first.longitude;
  for (final p in list.skip(1)) {
    if (p.latitude < south) south = p.latitude;
    if (p.latitude > north) north = p.latitude;
    if (p.longitude < west) west = p.longitude;
    if (p.longitude > east) east = p.longitude;
  }

  final latPad = ((minimumSpanDegrees - (north - south)) / 2).clamp(0, 90);
  final lngPad = ((minimumSpanDegrees - (east - west)) / 2).clamp(0, 180);

  return GeoBounds(
    southwest: GeoPoint(
      (south - latPad).clamp(-90.0, 90.0),
      (west - lngPad).clamp(-180.0, 180.0),
    ),
    northeast: GeoPoint(
      (north + latPad).clamp(-90.0, 90.0),
      (east + lngPad).clamp(-180.0, 180.0),
    ),
  );
}

/// A position [t] of the way from [from] to [to], for animating the rider's
/// marker between two reports instead of letting it jump.
///
/// Straight-line interpolation is accurate enough over the ~50–150 m a rider
/// covers between reports; great-circle maths would change nothing visible.
GeoPoint lerpGeoPoint(GeoPoint from, GeoPoint to, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return GeoPoint(
    from.latitude + (to.latitude - from.latitude) * clamped,
    from.longitude + (to.longitude - from.longitude) * clamped,
  );
}
