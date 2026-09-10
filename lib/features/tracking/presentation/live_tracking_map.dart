import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../orders/domain/entities/order_entities.dart';
import '../domain/map_viewport.dart';

/// Whether this build renders a real Google Map.
///
/// Opt-in with `--dart-define=GOOGLE_MAPS_ENABLED=true`. The Android key comes
/// from local.properties or the MAPS_API_KEY environment variable; without
/// both, leaving this off means the map widget is never built, so a build
/// with no key shows the text tracking view instead of a blank or crashing
/// map.
const bool kGoogleMapsEnabled = bool.fromEnvironment('GOOGLE_MAPS_ENABLED');

/// Live map for an order: rider, pickup and drop-off.
///
/// The camera frames all three once, then leaves the customer alone — the
/// first time they pan or zoom it stops following, and "Recenter" hands
/// control back. The rider's marker glides between reports rather than
/// jumping.
class LiveTrackingMap extends StatefulWidget {
  const LiveTrackingMap({required this.tracking, super.key});

  final OrderTracking tracking;

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;

  /// True once the customer has moved the camera themselves.
  bool _userMovedCamera = false;
  bool _initialFitDone = false;

  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addListener(() => setState(() {}));

  GeoPoint? _glideFrom;
  GeoPoint? _glideTo;

  @override
  void initState() {
    super.initState();
    _glideTo = _riderPoint(widget.tracking);
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _riderPoint(widget.tracking);
    if (next == null || next == _glideTo) return;

    // Start from where the marker is drawn right now, so a report arriving
    // mid-glide continues smoothly instead of snapping back.
    _glideFrom = _currentRiderPoint ?? next;
    _glideTo = next;
    _glide.forward(from: 0);

    if (!_userMovedCamera) _fitCamera();
  }

  @override
  void dispose() {
    _glide.dispose();
    _controller?.dispose();
    super.dispose();
  }

  GeoPoint? get _currentRiderPoint {
    final to = _glideTo;
    if (to == null) return null;
    final from = _glideFrom;
    if (from == null) return to;
    return lerpGeoPoint(from, to, Curves.easeInOut.transform(_glide.value));
  }

  static GeoPoint? _riderPoint(OrderTracking t) => t.hasRiderLocation
      ? GeoPoint(t.riderLatitude!, t.riderLongitude!)
      : null;

  List<GeoPoint> get _framedPoints {
    final t = widget.tracking;
    return [
      ?_glideTo,
      if (t.hasRestaurantLocation)
        GeoPoint(t.restaurantLatitude!, t.restaurantLongitude!),
      if (t.hasDeliveryLocation)
        GeoPoint(t.deliveryLatitude!, t.deliveryLongitude!),
    ];
  }

  Future<void> _fitCamera() async {
    final controller = _controller;
    final bounds = boundsFor(_framedPoints);
    if (controller == null || bounds == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(bounds.southwest.latitude, bounds.southwest.longitude),
            northeast: LatLng(bounds.northeast.latitude, bounds.northeast.longitude),
          ),
          56,
        ),
      );
    } catch (_) {
      // newLatLngBounds throws if the map has not been laid out yet. The next
      // update will fit it; there is nothing useful to show the customer.
    }
  }

  void _recenter() {
    setState(() => _userMovedCamera = false);
    _fitCamera();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracking;
    final rider = _currentRiderPoint;
    final stale = t.hasRiderLocation && t.isRiderLocationStaleAt(DateTime.now().toUtc());

    final markers = <Marker>{
      if (t.hasRestaurantLocation)
        Marker(
          markerId: const MarkerId('restaurant'),
          position: LatLng(t.restaurantLatitude!, t.restaurantLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: t.restaurantName.isEmpty ? 'Pickup' : t.restaurantName,
          ),
        ),
      if (t.hasDeliveryLocation)
        Marker(
          markerId: const MarkerId('delivery'),
          position: LatLng(t.deliveryLatitude!, t.deliveryLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Your address'),
        ),
      if (rider != null)
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(rider.latitude, rider.longitude),
          // Stock hues rather than custom artwork, so a missing asset can
          // never leave the rider invisible.
          icon: BitmapDescriptor.defaultMarkerWithHue(
            stale ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueAzure,
          ),
          // Keep the rider above the other two where they overlap.
          zIndexInt: 2,
          infoWindow: InfoWindow(
            title: t.riderName.isEmpty ? 'Your rider' : t.riderName,
          ),
        ),
    };

    final initial = boundsFor(_framedPoints);
    final centre = initial == null
        ? const LatLng(28.6139, 77.2090)
        : LatLng(
            (initial.southwest.latitude + initial.northeast.latitude) / 2,
            (initial.southwest.longitude + initial.northeast.longitude) / 2,
          );

    return Stack(
      children: [
        // A touch is the only reliable sign the customer took over the camera:
        // onCameraMoveStarted fires for our own animateCamera calls too, so it
        // cannot tell the two apart. Programmatic moves produce no pointer
        // events, so this only ever trips for a real gesture.
        Listener(
          onPointerDown: (_) => _userMovedCamera = true,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: centre, zoom: 14),
            markers: markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: (controller) {
              _controller = controller;
              if (!_initialFitDone) {
                _initialFitDone = true;
                _fitCamera();
              }
            },
          ),
        ),
        Positioned(
          right: 12,
          bottom: 96,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              tooltip: 'Recenter',
              icon: const Icon(Icons.my_location_rounded, color: AppColors.dark),
              onPressed: _recenter,
            ),
          ),
        ),
        if (stale)
          Positioned(
            left: 12,
            right: 64,
            bottom: 96,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Rider location updating soon…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
