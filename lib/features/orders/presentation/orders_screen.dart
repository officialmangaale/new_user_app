import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/models/app_models.dart';
import '../providers/orders_providers.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    const tabs = TabBar(
      tabs: [
        Tab(text: 'Active'),
        Tab(text: 'Completed'),
        Tab(text: 'Cancelled'),
        Tab(text: 'Grocery'),
      ],
    );
    final body = TabBarView(
      children: [
        _OrdersList(status: OrderStatus.active, embedded: embedded),
        _OrdersList(status: OrderStatus.completed, embedded: embedded),
        _OrdersList(status: OrderStatus.cancelled, embedded: embedded),
        // Grocery orders come from their own paginated endpoint, so they get
        // their own tab instead of being mixed into the food pages.
        _GroceryOrdersList(embedded: embedded),
      ],
    );
    return DefaultTabController(
      length: 4,
      child: embedded
          ? SafeArea(
              bottom: false,
              child: ColoredBox(
                color: AppColors.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.md,
                        AppSpacing.screenPadding,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        'My orders',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    tabs,
                    Expanded(child: body),
                  ],
                ),
              ),
            )
          : Scaffold(
              appBar: AppBar(title: const Text('My orders'), bottom: tabs),
              body: body,
            ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.status, required this.embedded});

  final OrderStatus status;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One history fetch backs all three tabs; the backend returns every order
    // and the tab filters locally, so switching tabs costs no extra request.
    final orders = ref.watch(ordersProvider);
    return AsyncView<List<DeliveryOrder>>(
      value: orders,
      onRetry: () => ref.invalidate(ordersProvider),
      isEmpty: (all) => all.where((o) => o.status == status).isEmpty,
      empty: EmptyState(
        icon: status == OrderStatus.active
            ? Icons.delivery_dining_outlined
            : Icons.receipt_long_outlined,
        title: status == OrderStatus.active
            ? 'No active orders'
            : 'Nothing here yet',
        message: 'Your ${status.name} orders will appear here.',
      ),
      builder: (all) {
        final filtered = all
            .where((order) => order.status == status)
            .toList(growable: false);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(ordersProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              embedded ? AppSpacing.navigationClearance + 24 : AppSpacing.md,
            ),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _OrderCard(order: filtered[index]),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final active = order.status == OrderStatus.active;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.light,
                  child: Icon(
                    active
                        ? Icons.delivery_dining_rounded
                        : Icons.storefront_rounded,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.store,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.date,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                OrderStatusBadge(status: order.status),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.itemCount} items • Order #${order.id}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '₹${order.total}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (order.isShared) ...[
              const SizedBox(height: 11),
              Row(
                children: [
                  const AppPill(
                    label: 'Shared order',
                    icon: Icons.people_alt_rounded,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You saved ₹${order.savings}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => active
                        ? context.push('/tracking/${order.id}')
                        : _details(context),
                    child: const Text('View details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => active
                        ? context.push('/tracking/${order.id}')
                        : context.go('/home'),
                    child: Text(active ? 'Track order' : 'Reorder'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _details(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.id}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('${order.itemCount} items from ${order.store}'),
              const Divider(height: 26),
              Row(
                children: [
                  const Expanded(child: Text('Order total')),
                  Text(
                    '₹${order.total}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              if (order.isShared) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('Shared-order savings')),
                    Text(
                      '₹${order.savings}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              AppButton(
                label: 'Download invoice',
                outlined: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      OrderStatus.active => ('On the way', AppColors.light, AppColors.dark),
      OrderStatus.completed => (
        'Delivered',
        const Color(0xFFEAF8EF),
        const Color(0xFF137333),
      ),
      OrderStatus.cancelled => (
        'Cancelled',
        const Color(0xFFFFEDEE),
        AppColors.error,
      ),
    };
    return AppPill(
      label: label,
      background: background,
      foreground: foreground,
    );
  }
}

class _GroceryOrdersList extends ConsumerStatefulWidget {
  const _GroceryOrdersList({required this.embedded});

  final bool embedded;

  @override
  ConsumerState<_GroceryOrdersList> createState() =>
      _GroceryOrdersListState();
}

class _GroceryOrdersListState extends ConsumerState<_GroceryOrdersList> {
  static const _pageSize = 10;

  final List<GroceryOrderSummary> _orders = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final result = await ref.read(fetchGroceryOrdersUseCaseProvider)(
      page: 1,
      limit: _pageSize,
    );
    if (!mounted) return;
    final page = result.dataOrNull;
    setState(() {
      _loading = false;
      _failed = page == null;
      if (page != null) {
        _orders
          ..clear()
          ..addAll(page.orders);
        _page = 1;
        _hasMore = page.hasMore;
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _orders.isEmpty;
      _failed = false;
    });
    await _loadFirstPage();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final result = await ref.read(fetchGroceryOrdersUseCaseProvider)(
      page: _page + 1,
      limit: _pageSize,
    );
    if (!mounted) return;
    final page = result.dataOrNull;
    setState(() {
      _loadingMore = false;
      if (page == null) return;
      // A new order placed meanwhile pushes older ones onto the next page;
      // skip ids already shown so nothing appears twice.
      final shown = {for (final order in _orders) order.id};
      _orders.addAll(page.orders.where((order) => !shown.contains(order.id)));
      _page += 1;
      _hasMore = page.hasMore;
    });
    if (page == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more grocery orders.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final bottom = widget.embedded
        ? AppSpacing.navigationClearance + 24
        : AppSpacing.md;
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(AppSpacing.md, 48, AppSpacing.md, bottom),
          children: [
            EmptyState(
              icon: _failed
                  ? Icons.cloud_off_rounded
                  : Icons.local_grocery_store_outlined,
              title: _failed
                  ? 'Could not load grocery orders'
                  : 'No grocery orders yet',
              message: _failed
                  ? 'Pull down to try again.'
                  : 'Grocery orders you place will appear here.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          bottom,
        ),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _orders.length) {
            return Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      key: const ValueKey('grocery_orders_load_more'),
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    ),
            );
          }
          return _GroceryOrderCard(order: _orders[index]);
        },
      ),
    );
  }
}

class _GroceryOrderCard extends StatelessWidget {
  const _GroceryOrderCard({required this.order});

  final GroceryOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final stopped = order.status == 'rejected' || order.status == 'cancelled';
    final (background, foreground) = stopped
        ? (const Color(0xFFFFEDEE), AppColors.error)
        : order.status == 'delivered'
        ? (const Color(0xFFEAF8EF), const Color(0xFF137333))
        : (AppColors.light, AppColors.dark);
    return Card(
      key: ValueKey('grocery_order_${order.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.light,
                  child: Icon(
                    Icons.local_grocery_store_rounded,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.merchantName.isEmpty
                            ? 'Grocery order'
                            : order.merchantName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(order.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppPill(
                  label: order.statusLabel.isEmpty
                      ? order.status
                      : order.statusLabel,
                  background: background,
                  foreground: foreground,
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} • Grocery order #${order.id}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '₹${order.total.toStringAsFixed(order.total == order.total.roundToDouble() ? 0 : 2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    context.push('/tracking/${order.id}?mode=grocery'),
                child: Text(order.isFinished ? 'View order' : 'Track order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]}, $hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
}
