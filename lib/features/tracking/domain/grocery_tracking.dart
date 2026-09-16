/// Progress of a grocery order for the tracking screen.
///
/// Grocery orders are packed and delivered by the shop. Platform riders are
/// not assigned to them in this phase, so none of the food rider steps apply
/// and nothing here may suggest a rider exists.
///
/// Pure, so every rule is testable without a device.
library;

/// Backend statuses of a grocery order that is still moving forward, in order.
const List<String> groceryTrackingStatuses = [
  'placed',
  'accepted',
  'packing',
  'packed',
  'out_for_delivery',
  'delivered',
];

/// Timeline labels, index-aligned with [groceryTrackingStatuses].
const List<String> groceryTrackingStepLabels = [
  'Order placed',
  'Accepted by the shop',
  'Packing',
  'Packed',
  'Out for delivery',
  'Delivered',
];

/// Rejected by the shop or cancelled: the order stopped before delivery.
bool isGroceryOrderStopped(String status) =>
    const {'rejected', 'cancelled'}.contains(status.trim().toLowerCase());

/// The furthest step the order reached. A stopped order has no step of its
/// own, so it uses the furthest status recorded in its timeline.
int groceryTrackingIndex(String status, {Iterable<String> reached = const []}) {
  final direct = groceryTrackingStatuses.indexOf(status.trim().toLowerCase());
  if (direct >= 0) return direct;
  var furthest = 0;
  for (final step in reached) {
    final index = groceryTrackingStatuses.indexOf(step.trim().toLowerCase());
    if (index > furthest) furthest = index;
  }
  return furthest;
}

/// Headline for the current status.
String groceryStatusTitle(String status) =>
    switch (status.trim().toLowerCase()) {
      'placed' => 'Waiting for the shop to accept',
      'accepted' => 'Accepted by the shop',
      'packing' => 'Packing your order',
      'packed' => 'Packed and ready',
      'out_for_delivery' => 'Out for delivery',
      'delivered' => 'Delivered',
      'rejected' => 'Declined by the shop',
      'cancelled' => 'Order cancelled',
      _ => 'Order update',
    };
