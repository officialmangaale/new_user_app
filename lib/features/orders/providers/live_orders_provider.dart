import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../app_state/providers/app_controller.dart';
import 'orders_providers.dart';

/// An order the customer is still waiting for, as the home banner and the
/// ongoing notification show it.
class LiveOrder {
  const LiveOrder({
    required this.id,
    required this.store,
    required this.mode,
    this.statusLabel = '',
  });

  final String id;
  final String store;
  final DeliveryMode mode;

  /// Known for grocery orders from the list; for food orders the banner reads
  /// it from the order's tracking.
  final String statusLabel;

  String get trackingPath =>
      mode == DeliveryMode.grocery ? '/tracking/$id?mode=grocery' : '/tracking/$id';
}

/// Food and grocery orders that have not finished yet, newest first. Empty for
/// guests. A failure on one list never hides the other, and never throws: the
/// banner is a convenience, not a reason to show an error on Home.
final liveOrdersProvider = FutureProvider.autoDispose<List<LiveOrder>>((
  ref,
) async {
  final authenticated = ref.watch(
    appControllerProvider.select((s) => s.authenticated),
  );
  if (!authenticated) return const <LiveOrder>[];

  final live = <LiveOrder>[];
  try {
    final food = await ref.watch(activeOrdersProvider.future);
    for (final order in food) {
      live.add(
        LiveOrder(
          id: order.id,
          store: order.store,
          mode: DeliveryMode.food,
        ),
      );
    }
  } catch (_) {
    // Food list unavailable; show whatever else is known.
  }
  try {
    final result = await ref.watch(fetchGroceryOrdersUseCaseProvider)(
      page: 1,
      limit: 10,
    );
    final page = result.dataOrNull;
    if (page != null) {
      for (final order in page.orders.where((o) => !o.isFinished)) {
        live.add(
          LiveOrder(
            id: order.id,
            store: order.merchantName,
            mode: DeliveryMode.grocery,
            statusLabel: order.statusLabel,
          ),
        );
      }
    }
  } catch (_) {
    // Grocery list unavailable.
  }
  return live;
});
