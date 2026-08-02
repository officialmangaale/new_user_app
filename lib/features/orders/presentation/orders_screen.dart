import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../shared/mock_data/mock_data.dart';
import '../../../shared/models/app_models.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersList(status: OrderStatus.active),
            _OrdersList(status: OrderStatus.completed),
            _OrdersList(status: OrderStatus.cancelled),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final orders = MockData.orders
        .where((order) => order.status == status)
        .toList();
    if (orders.isEmpty) {
      return EmptyState(
        icon: status == OrderStatus.active
            ? Icons.delivery_dining_outlined
            : Icons.receipt_long_outlined,
        title: status == OrderStatus.active
            ? 'No active orders'
            : 'Nothing here yet',
        message: 'Your ${status.name} orders will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _OrderCard(order: orders[index]),
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
