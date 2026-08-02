class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class TrackingSnapshot {
  const TrackingSnapshot({
    required this.rider,
    required this.destination,
    required this.route,
    required this.etaMinutes,
    required this.distanceKm,
  });

  final MapCoordinate rider;
  final MapCoordinate destination;
  final List<MapCoordinate> route;
  final int etaMinutes;
  final double distanceKm;
}

abstract interface class MapTrackingService {
  Stream<TrackingSnapshot> watchOrder(String orderId);
}

class PlaceholderMapTrackingService implements MapTrackingService {
  const PlaceholderMapTrackingService();

  @override
  Stream<TrackingSnapshot> watchOrder(String orderId) {
    return Stream.value(
      const TrackingSnapshot(
        rider: MapCoordinate(12.9784, 77.6408),
        destination: MapCoordinate(12.9719, 77.6412),
        route: [
          MapCoordinate(12.9784, 77.6408),
          MapCoordinate(12.9751, 77.6420),
          MapCoordinate(12.9719, 77.6412),
        ],
        etaMinutes: 11,
        distanceKm: 1.8,
      ),
    );
  }
}
