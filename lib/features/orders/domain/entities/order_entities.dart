enum OrderStatus { active, completed, cancelled }

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.store,
    required this.date,
    required this.itemCount,
    required this.total,
    required this.status,
    required this.savings,
    this.isShared = false,
  });

  final String id;
  final String store;
  final String date;
  final int itemCount;
  final int total;
  final OrderStatus status;
  final int savings;
  final bool isShared;
}

class OrderTracking {
  const OrderTracking({
    required this.orderId,
    required this.status,
    required this.statusLabel,
    required this.etaMinutes,
    required this.riderName,
    required this.riderPhone,
    this.riderLatitude,
    this.riderLongitude,
    this.riderMapsUrl = '',
    this.riderLocationUpdatedAt,
    this.restaurantName = '',
    this.restaurantLatitude,
    this.restaurantLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
  });

  final String orderId;
  final String status;
  final String statusLabel;
  final int etaMinutes;
  final String riderName;
  final String riderPhone;

  /// The rider's last known position. Null until a rider is assigned — the
  /// backend only sends these once the order actually has one.
  final double? riderLatitude;
  final double? riderLongitude;

  /// Google Maps deep link for [riderLatitude]/[riderLongitude], supplied by
  /// the backend so the app never has to build the URL itself.
  final String riderMapsUrl;

  /// When the rider last reported a position. Null when unknown — an older
  /// deployment, or no report yet.
  final DateTime? riderLocationUpdatedAt;

  /// Pickup point. Null when the restaurant has no stored coordinates.
  final String restaurantName;
  final double? restaurantLatitude;
  final double? restaurantLongitude;

  /// Drop-off point, from the order's delivery address.
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  /// A rider who has not reported for this long is shown as "updating" rather
  /// than as a live position. Their app sends every 20 seconds on an active
  /// delivery, so 90 seconds is several missed reports, not a single slow
  /// one.
  static const Duration staleAfter = Duration(seconds: 90);

  /// True when there is a real position to show on a map or hand to Maps.
  bool get hasRiderLocation => isUsableCoordinate(riderLatitude, riderLongitude);

  bool get hasRestaurantLocation =>
      isUsableCoordinate(restaurantLatitude, restaurantLongitude);

  bool get hasDeliveryLocation =>
      isUsableCoordinate(deliveryLatitude, deliveryLongitude);

  /// Whether the last known rider position is too old to present as live.
  ///
  /// A position with no timestamp is treated as stale: without knowing its
  /// age, calling it live would be a guess.
  bool isRiderLocationStaleAt(DateTime now) {
    final updated = riderLocationUpdatedAt;
    if (updated == null) return true;
    return now.difference(updated) > staleAfter;
  }
}

/// A coordinate pair worth putting on a map.
///
/// Rejects nulls, out-of-range values, and 0,0 — the value a missing position
/// most often collapses to, which would drop a marker in the Gulf of Guinea.
bool isUsableCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (latitude.isNaN || longitude.isNaN) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  return !(latitude == 0 && longitude == 0);
}

class BillSummary {
  const BillSummary({
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.packagingCharge,
    required this.cgst,
    required this.sgst,
    required this.taxAmount,
    required this.platformFee,
    required this.roundOff,
    required this.grandTotal,
    required this.valid,
    required this.message,
  });

  final int subtotal;
  final int discount;
  final int deliveryFee;
  final int packagingCharge;
  final double cgst;
  final double sgst;
  final double taxAmount;
  final int platformFee;
  final double roundOff;
  final int grandTotal;
  final bool valid;
  final String message;
}

class CouponResult {
  const CouponResult({
    required this.valid,
    required this.code,
    required this.discountAmount,
    required this.message,
  });

  final bool valid;
  final String code;
  final int discountAmount;
  final String message;
}

class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.bill,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final BillSummary bill;
}
