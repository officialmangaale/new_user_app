/// When the customer's tracking screen refreshes.
///
/// The order-status WebSocket carries status changes only. Rider positions are
/// written by rider-service, which never touches that socket, so without a
/// poll the rider's marker would move only when the order status changed —
/// at pickup, and again at delivery — and look frozen in between.
///
/// Polling the tracking snapshot is therefore the source of truth for
/// position, and the socket an accelerator for status. This also covers the
/// socket dropping, which it previously never recovered from.
///
/// Pure functions, so the rules are testable without a device.
library;

/// The rider app reports every 20 seconds on an active delivery (every 30
/// while idle; see rider-app rider_location_service.dart). Polling at 15
/// means a new position is picked up within one poll of arriving, at the cost
/// of occasionally re-fetching an unchanged one.
const Duration trackingPollInterval = Duration(seconds: 15);

/// While a delivery partner is being found. Rider assignment is not pushed on
/// the order-status socket (restaurant-service announces it to the
/// restaurant only), so polling is how the customer learns of it; 5 seconds
/// keeps "Finding a delivery partner" from lingering after a rider accepts.
const Duration trackingAwaitingRiderPollInterval = Duration(seconds: 5);

/// How often to refresh right now.
Duration trackingPollIntervalFor({required bool awaitingRider}) =>
    awaitingRider ? trackingAwaitingRiderPollInterval : trackingPollInterval;

/// Whether a poll tick should refresh, given when the snapshot was last
/// requested (by a poll or a socket event).
bool isTrackingRefreshDue({
  required DateTime? lastRefreshAt,
  required DateTime now,
  required bool awaitingRider,
}) {
  if (lastRefreshAt == null) return true;
  return now.difference(lastRefreshAt) >=
      trackingPollIntervalFor(awaitingRider: awaitingRider);
}

/// Order statuses after which nothing more will change.
const Set<String> terminalTrackingStatuses = {
  'delivered',
  'completed',
  'done',
  'cancelled',
  'canceled',
  'rejected',
  'declined',
  'failed',
};

bool isTerminalTrackingStatus(String status) =>
    terminalTrackingStatuses.contains(status.trim().toLowerCase());

/// Whether the screen should keep polling.
///
/// Stops for a terminal order — it will never change again — and while the
/// app is in the background, where a map nobody can see is not worth the
/// battery or the requests. It resumes when the app returns.
bool shouldPollTracking({
  required String status,
  required bool appInForeground,
}) {
  if (!appInForeground) return false;
  return !isTerminalTrackingStatus(status);
}
