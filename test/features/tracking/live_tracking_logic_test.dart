import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/tracking/domain/map_viewport.dart';
import 'package:turquoise_delivery/features/tracking/domain/tracking_refresh_policy.dart';

void main() {
  group('polling', () {
    // The order-status socket never carries rider positions, so without this
    // the marker only moved when the order status changed.
    test('polls an active order in the foreground', () {
      for (final status in ['confirmed', 'preparing', 'picked_up', 'out_for_delivery']) {
        expect(shouldPollTracking(status: status, appInForeground: true), isTrue,
            reason: status);
      }
    });

    test('stops for a finished order — it will never change again', () {
      for (final status in terminalTrackingStatuses) {
        expect(shouldPollTracking(status: status, appInForeground: true), isFalse,
            reason: status);
      }
    });

    test('pauses in the background, where nobody can see the map', () {
      expect(shouldPollTracking(status: 'out_for_delivery', appInForeground: false),
          isFalse);
    });

    test('terminal matching tolerates casing and whitespace', () {
      expect(isTerminalTrackingStatus(' Delivered '), isTrue);
      expect(isTerminalTrackingStatus('CANCELLED'), isTrue);
      expect(isTerminalTrackingStatus('failed'), isTrue,
          reason: 'the old local set was missing this one');
    });

    test('the interval matches the rider app reporting interval', () {
      expect(trackingPollInterval, const Duration(seconds: 15));
    });
  });

  group('usable coordinates', () {
    test('a real position is usable', () {
      expect(isUsableCoordinate(28.4494, 77.0532), isTrue);
    });

    // 0,0 is what a missing position most often collapses to, and would drop
    // a marker off the coast of West Africa.
    test('0,0 is rejected', () {
      expect(isUsableCoordinate(0, 0), isFalse);
    });

    test('nulls, NaN and out-of-range values are rejected', () {
      expect(isUsableCoordinate(null, 77), isFalse);
      expect(isUsableCoordinate(28, null), isFalse);
      expect(isUsableCoordinate(double.nan, 77), isFalse);
      expect(isUsableCoordinate(91, 77), isFalse);
      expect(isUsableCoordinate(28, 181), isFalse);
      expect(isUsableCoordinate(-91, 77), isFalse);
    });

    test('a legitimate zero on one axis is still usable', () {
      // The equator and the prime meridian are real places.
      expect(isUsableCoordinate(0, 77), isTrue);
      expect(isUsableCoordinate(28, 0), isTrue);
    });
  });

  group('staleness', () {
    final now = DateTime.utc(2026, 9, 10, 12);

    OrderTracking withUpdate(DateTime? at) => OrderTracking(
          orderId: '1', status: 'out_for_delivery', statusLabel: '',
          etaMinutes: 0, riderName: '', riderPhone: '',
          riderLatitude: 28.4, riderLongitude: 77.0,
          riderLocationUpdatedAt: at,
        );

    test('a recent report is live', () {
      expect(withUpdate(now.subtract(const Duration(seconds: 20)))
          .isRiderLocationStaleAt(now), isFalse);
    });

    test('several missed reports is stale', () {
      expect(withUpdate(now.subtract(const Duration(seconds: 120)))
          .isRiderLocationStaleAt(now), isTrue);
    });

    // Without a timestamp we cannot know the age, so calling it live would be
    // a guess.
    test('a position with no timestamp is treated as stale', () {
      expect(withUpdate(null).isRiderLocationStaleAt(now), isTrue);
    });
  });

  group('camera bounds', () {
    test('frames every point', () {
      final b = boundsFor(const [
        GeoPoint(28.40, 77.00),
        GeoPoint(28.50, 77.10),
        GeoPoint(28.45, 77.05),
      ])!;
      expect(b.southwest.latitude, lessThanOrEqualTo(28.40));
      expect(b.northeast.latitude, greaterThanOrEqualTo(28.50));
      expect(b.southwest.longitude, lessThanOrEqualTo(77.00));
      expect(b.northeast.longitude, greaterThanOrEqualTo(77.10));
    });

    // A single point, or a rider standing at the restaurant, would otherwise
    // zoom to street level.
    test('pads a single point to a neighbourhood view', () {
      final b = boundsFor(const [GeoPoint(28.45, 77.05)])!;
      expect(b.northeast.latitude - b.southwest.latitude,
          closeTo(minimumSpanDegrees, 1e-9));
      expect(b.northeast.longitude - b.southwest.longitude,
          closeTo(minimumSpanDegrees, 1e-9));
    });

    test('coincident points are padded, not collapsed', () {
      final b = boundsFor(const [GeoPoint(28.45, 77.05), GeoPoint(28.45, 77.05)])!;
      expect(b.northeast.latitude - b.southwest.latitude, greaterThan(0));
    });

    test('no points means no bounds', () {
      expect(boundsFor(const []), isNull);
    });
  });

  group('marker glide', () {
    const from = GeoPoint(28.40, 77.00);
    const to = GeoPoint(28.50, 77.10);

    test('starts at the old position and ends at the new one', () {
      expect(lerpGeoPoint(from, to, 0), from);
      expect(lerpGeoPoint(from, to, 1), to);
    });

    test('passes through the midpoint', () {
      final mid = lerpGeoPoint(from, to, 0.5);
      expect(mid.latitude, closeTo(28.45, 1e-9));
      expect(mid.longitude, closeTo(77.05, 1e-9));
    });

    test('never overshoots, whatever the animation curve supplies', () {
      expect(lerpGeoPoint(from, to, 1.5), to);
      expect(lerpGeoPoint(from, to, -0.5), from);
    });
  });
}
