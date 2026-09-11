import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/features/tracking/domain/rider_assignment_state.dart';

/// Order 13279 was accepted and preparing with no rider assigned, yet the
/// screen showed a "Delivery partner" card, "Assigned by restaurant", a Chat
/// button and a rider on the map. These pin what may be said instead.
void main() {
  RiderAssignmentState state(String status, [String riderName = '']) =>
      riderAssignmentState(status: status, riderName: riderName);

  group('no rider assigned', () {
    // The reported case.
    test('an accepted order with no rider is finding one', () {
      for (final status in ['confirmed', 'preparing', 'ready']) {
        expect(state(status), RiderAssignmentState.finding, reason: status);
      }
    });

    // Dispatch waits for restaurant acceptance, so claiming a partner is being
    // found before then would be another untrue statement.
    test('before the restaurant accepts, it is waiting on the restaurant', () {
      expect(state('pending'), RiderAssignmentState.awaitingRestaurant);
      expect(state(' PENDING '), RiderAssignmentState.awaitingRestaurant);
    });

    test('an unknown status is treated as not yet accepted, not as searching', () {
      expect(state(''), RiderAssignmentState.awaitingRestaurant);
    });

    // A cancelled order has no delivery partner to describe.
    test('a finished order with no rider says nothing about one', () {
      for (final status in ['cancelled', 'rejected', 'delivered', 'completed']) {
        expect(state(status), RiderAssignmentState.none, reason: status);
      }
    });
  });

  group('rider assigned', () {
    test('a named rider is assigned whatever the status', () {
      for (final status in ['preparing', 'ready', 'out_for_delivery', 'delivered']) {
        expect(state(status, 'Amrit'), RiderAssignmentState.assigned, reason: status);
      }
    });

    // A whitespace name is the backend's empty value, not a rider.
    test('a blank name is not a rider', () {
      expect(state('preparing', '   '), RiderAssignmentState.finding);
    });
  });

  group('wording', () {
    test('the finding state uses the agreed headline', () {
      expect(riderSearchTitle(RiderAssignmentState.finding),
          'Finding a delivery partner');
    });

    // None of the non-assigned wording may claim a rider exists.
    test('no non-assigned wording implies someone is assigned', () {
      for (final s in [
        RiderAssignmentState.finding,
        RiderAssignmentState.awaitingRestaurant,
      ]) {
        final text = '${riderSearchTitle(s)} ${riderSearchSubtitle(s)}'.toLowerCase();
        expect(text, isNot(contains('assigned by')), reason: '$s');
        expect(text, isNot(contains('is on the way')), reason: '$s');
        expect(text, isNot(contains('is handling')), reason: '$s');
        expect(riderSearchTitle(s), isNotEmpty, reason: '$s');
      }
    });

    test('assigned and none states produce no search wording', () {
      for (final s in [RiderAssignmentState.assigned, RiderAssignmentState.none]) {
        expect(riderSearchTitle(s), isEmpty, reason: '$s');
        expect(riderSearchSubtitle(s), isEmpty, reason: '$s');
      }
    });
  });
}
