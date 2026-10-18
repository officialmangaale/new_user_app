import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/ongoing_order_notification.dart';
import '../../../orders/providers/live_orders_provider.dart';
import '../../../orders/providers/orders_providers.dart';

/// "Your order is on its way" strip at the top of Home, shown while the
/// customer has an unfinished order. One tap opens that order's tracking.
///
/// It also keeps the ongoing notification in the shade in step with the same
/// list, so the order stays visible when the app is minimised or the phone is
/// locked.
class LiveOrderBanner extends ConsumerStatefulWidget {
  const LiveOrderBanner({super.key});

  @override
  ConsumerState<LiveOrderBanner> createState() => _LiveOrderBannerState();
}

class _LiveOrderBannerState extends ConsumerState<LiveOrderBanner>
    with WidgetsBindingObserver {
  static const _refreshEvery = Duration(seconds: 45);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    ref.invalidate(liveOrdersProvider);
    ref.invalidate(activeOrdersProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Shade follows the list: new/changed orders are shown, finished ones
    // cleared.
    ref.listen<AsyncValue<List<LiveOrder>>>(liveOrdersProvider, (_, next) {
      final orders = next.value;
      if (orders == null) return;
      unawaited(
        OngoingOrderNotification.sync([
          for (final o in orders)
            LiveOrderNotice(
              orderId: o.id,
              title: o.store.isEmpty ? 'Order #${o.id}' : o.store,
              body: o.statusLabel.isEmpty
                  ? 'Order #${o.id} in progress'
                  : o.statusLabel,
              grocery: o.trackingPath.contains('mode=grocery'),
            ),
        ]),
      );
    });

    final orders = ref.watch(liveOrdersProvider).value ?? const <LiveOrder>[];
    if (orders.isEmpty) return const SizedBox.shrink();
    final first = orders.first;

    var label = first.statusLabel;
    if (first.statusLabel.isEmpty) {
      final tracking = ref
          .watch(orderTrackingProvider(OrderTrackingRequest(orderId: first.id)))
          .value;
      if (tracking != null) {
        label = tracking.statusLabel.trim().isNotEmpty
            ? tracking.statusLabel.trim()
            : LiveOrderNotice.labelFor(tracking.status);
      }
    }
    if (label.isEmpty) label = 'Order in progress';
    final extra = orders.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('live-order-banner'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(first.trackingPath),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    color: AppColors.onPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.store.isEmpty
                            ? 'Order #${first.id}'
                            : first.store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        extra > 0 ? '$label · +$extra more' : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Track order',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
