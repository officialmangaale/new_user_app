import 'map_viewport.dart';

List<GeoPoint> decodeEncodedPolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final latResult = _decodeValue(encoded, index);
    index = latResult.nextIndex;
    lat += latResult.delta;

    if (index >= encoded.length) break;
    final lngResult = _decodeValue(encoded, index);
    index = lngResult.nextIndex;
    lng += lngResult.delta;

    points.add(GeoPoint(lat / 1e5, lng / 1e5));
  }
  return points;
}

_DecodedValue _decodeValue(String encoded, int start) {
  var result = 0;
  var shift = 0;
  var index = start;
  while (index < encoded.length) {
    final byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
    if (byte < 0x20) break;
  }
  final delta = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  return _DecodedValue(delta, index);
}

class _DecodedValue {
  const _DecodedValue(this.delta, this.nextIndex);

  final int delta;
  final int nextIndex;
}
