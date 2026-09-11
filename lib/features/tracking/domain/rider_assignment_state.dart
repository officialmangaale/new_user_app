/// What the tracking screen may truthfully say about the delivery partner.
///
/// The screen used to show a rider card whenever it had nothing better: an
/// unnamed "Delivery partner", "Assigned by restaurant" in place of the
/// missing phone number, a Chat button that always opened, and a rider pin on
/// the map. With no rider assigned, all of that described someone who did not
/// exist.
///
/// The backend sends `rider: null` until a rider is assigned, so an empty rider
/// name means nobody is assigned yet — not an unnamed rider.
///
/// Kept free of widgets so every branch is testable.
library;

import 'tracking_refresh_policy.dart';

enum RiderAssignmentState {
  /// A rider is assigned. Show their card, and the call and chat actions.
  assigned,

  /// The restaurant has accepted and a rider is being found — by platform
  /// dispatch, or by the restaurant assigning one of its own.
  finding,

  /// The restaurant has not accepted yet. Rider dispatch waits for acceptance,
  /// so saying a partner is being found would not be true yet.
  awaitingRestaurant,

  /// The order is finished without a rider (cancelled, rejected) — there is
  /// nothing about a delivery partner to say.
  none,
}

/// The order status before the restaurant has accepted.
///
/// `pending` is the only pre-acceptance value in restaurant-service's status
/// contract (services/order_status_contract.go). Rider dispatch there waits
/// until the order is confirmed, preparing or ready.
const String _awaitingRestaurantStatus = 'pending';

RiderAssignmentState riderAssignmentState({
  required String status,
  required String riderName,
}) {
  if (riderName.trim().isNotEmpty) return RiderAssignmentState.assigned;

  final normalized = status.trim().toLowerCase();
  if (isTerminalTrackingStatus(normalized)) return RiderAssignmentState.none;
  if (normalized == _awaitingRestaurantStatus || normalized.isEmpty) {
    return RiderAssignmentState.awaitingRestaurant;
  }
  return RiderAssignmentState.finding;
}

/// Headline for the delivery-partner card in a non-assigned state.
String riderSearchTitle(RiderAssignmentState state) => switch (state) {
  RiderAssignmentState.finding => 'Finding a delivery partner',
  RiderAssignmentState.awaitingRestaurant => 'Waiting for the restaurant',
  RiderAssignmentState.assigned || RiderAssignmentState.none => '',
};

/// Supporting line for [riderSearchTitle].
String riderSearchSubtitle(RiderAssignmentState state) => switch (state) {
  RiderAssignmentState.finding =>
    "We'll share their name and number here as soon as one is assigned.",
  RiderAssignmentState.awaitingRestaurant =>
    "Once the restaurant confirms your order, we'll find you a delivery partner.",
  RiderAssignmentState.assigned || RiderAssignmentState.none => '',
};
