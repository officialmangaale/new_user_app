/// Which step of the tracking screen's seven-step timeline an order is on.
///
/// Two backend fields describe a delivery, and neither is enough alone:
///   - `order_status` (restaurant-service's canonical lifecycle): confirmed,
///     preparing, ready, out_for_delivery, delivered. A rider's pickup moves
///     it straight to out_for_delivery, so it cannot say "picked up".
///   - `delivery_status` (the delivery on the same order): rider_assigned,
///     picked_up, out_for_delivery, delivered. Written when a rider is
///     assigned and at each canonical rider step.
///
/// Previously only `order_status` was read, and `ready` was drawn as "Rider
/// assigned" whether or not anyone was — while a real assignment showed
/// nothing until pickup.
///
/// Pure, so every rule is testable without a device.
library;

/// The timeline steps, in order. Indices are what [trackingTimelineIndex]
/// returns.
const List<String> trackingTimelineSteps = [
  'Order confirmed',
  'Preparing',
  'Rider assigned',
  'Picked up',
  'On the way',
  'Arriving soon',
  'Delivered',
];

const int _confirmed = 0;
const int _preparing = 1;
const int _riderAssigned = 2;
const int _pickedUp = 3;
const int _onTheWay = 4;
const int _arriving = 5;
const int _delivered = 6;

int _orderStatusIndex(String status) => switch (status) {
  'preparing' ||
  'packing' ||
  'ready' ||
  'ready_to_serve' ||
  'packed' => _preparing,
  'picked_up' => _pickedUp,
  'out_for_delivery' || 'on_the_way' => _onTheWay,
  'delivered' || 'completed' || 'done' => _delivered,
  _ => _confirmed,
};

/// -1 when [status] says nothing about the delivery's progress.
int _deliveryStatusIndex(String status) => switch (status) {
  'rider_assigned' ||
  'rider_arrived_restaurant' ||
  'accepted' => _riderAssigned,
  'picked_up' => _pickedUp,
  'out_for_delivery' || 'on_the_way' => _onTheWay,
  'arrived_at_customer' || 'arrived' || 'reached_customer' => _arriving,
  'delivered' => _delivered,
  _ => -1,
};

int trackingTimelineIndex({
  required String orderStatus,
  String deliveryStatus = '',
  bool riderAssigned = false,
}) {
  final order = _orderStatusIndex(orderStatus.trim().toLowerCase());
  final delivery = _deliveryStatusIndex(deliveryStatus.trim().toLowerCase());

  if (order == _delivered) return _delivered;
  // Once the rider has the food, the delivery status is the more precise of
  // the two: the order is already out_for_delivery at pickup.
  if (delivery >= _pickedUp) return delivery;

  var index = order > delivery ? order : delivery;
  if (riderAssigned && index < _riderAssigned) index = _riderAssigned;
  return index;
}
