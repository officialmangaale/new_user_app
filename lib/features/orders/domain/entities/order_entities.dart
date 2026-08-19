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
  });

  final String orderId;
  final String status;
  final String statusLabel;
  final int etaMinutes;
  final String riderName;
  final String riderPhone;
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
