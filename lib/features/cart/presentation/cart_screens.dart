import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../orders/data/repositories/orders_repository_impl.dart';
import '../../app_state/providers/app_controller.dart';
import '../../orders/providers/orders_providers.dart';
import '../../authentication/presentation/auth_screens.dart';
import '../providers/cart_controller.dart';
import '../providers/checkout_view_model.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _instructions = TextEditingController();

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartLinesProvider);
    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your cart')),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is waiting',
          message:
              'Add something delicious or a few daily essentials to get started.',
          action: AppButton(
            label: 'Start browsing',
            expand: false,
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }
    final grocery = lines.first.item.type == CatalogItemType.grocery;
    final total = ref.watch(cartTotalProvider);

    // Every figure below comes from /customer-web/cart/validate. The app must
    // not invent tax, delivery or packaging amounts — the customer has to see
    // exactly what the backend will charge.
    final bill = ref.watch(cartBillProvider).value;
    final taxes = (bill?.taxAmount ?? 0).round();
    final platformFee = bill?.platformFee ?? 0;
    final packagingFee = bill?.packagingCharge ?? 0;
    final deliveryFee = bill?.deliveryFee ?? 0;
    final couponDiscount = bill?.discount ?? 0;
    final payable = bill?.grandTotal ?? total;
    return Scaffold(
      appBar: AppBar(
        title: Text(grocery ? 'Your grocery basket' : 'Your food cart'),
        actions: [
          TextButton(
            onPressed: ref.read(cartControllerProvider.notifier).clearCart,
            child: const Text('Clear'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.xs,
          AppSpacing.screenPadding,
          152,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.dark,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          lines.first.item.store,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  for (final line in lines) ...[
                    _CartLineTile(line: line),
                    if (line != lines.last) const Divider(height: 24),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _instructions,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: grocery
                  ? 'Packing instructions'
                  : 'Add cooking instructions',
              prefixIcon: const Icon(Icons.edit_note_rounded),
              hintText: grocery
                  ? 'e.g. No plastic bags'
                  : 'e.g. Less spicy, no cutlery',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _AddressCard(),
          const SizedBox(height: AppSpacing.lg),
          _BillDetails(
            total: total,
            taxes: taxes,
            platformFee: platformFee,
            packagingFee: packagingFee,
            deliveryFee: deliveryFee,
            couponDiscount: couponDiscount,
            payable: payable,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹$payable',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Including taxes',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Proceed to checkout',
                  onPressed: () {
                    final authenticated = ref
                        .read(appControllerProvider)
                        .authenticated;
                    final route = _checkoutRoute(_instructions.text);
                    if (authenticated) {
                      context.push(route);
                    } else {
                      ProtectedActionSheet.show(context, route);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

String _checkoutRoute(String instructions) {
  final trimmed = instructions.trim();
  if (trimmed.isEmpty) return '/checkout';
  return '/checkout?instructions=${Uri.encodeQueryComponent(trimmed)}';
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNetworkImage(
          url: line.item.imageUrl,
          width: 66,
          height: 66,
          borderRadius: 13,
          semanticLabel: line.item.name,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              if (line.optionsLabel.isNotEmpty) ...[
                Text(
                  line.optionsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
              ],
              Text(
                '₹${line.selection.unitPrice} each',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            QuantityControl(
              quantity: line.quantity,
              compact: true,
              onAdd: () => ref
                  .read(cartControllerProvider.notifier)
                  .addItem(line.item),
              onRemove: () => ref
                  .read(cartControllerProvider.notifier)
                  .removeItem(line.lineId),
            ),
            const SizedBox(height: 5),
            Text(
              '₹${line.total}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(
              height: 32,
              child: TextButton(
                onPressed: () => ref
                    .read(cartControllerProvider.notifier)
                    .removeLine(line.lineId),
                child: const Text('Remove'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticated = ref.watch(
      appControllerProvider.select((state) => state.authenticated),
    );
    final addresses = authenticated
        ? ref.watch(addressesProvider).value ?? const <CustomerAddress>[]
        : const <CustomerAddress>[];
    final address = _preferredAddress(addresses);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.home_rounded, color: AppColors.dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address == null
                            ? 'Delivery address'
                            : _addressTitle(address),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        address?.singleLine ??
                            'Confirm your address before placing the order',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(
                    '/info/${Uri.encodeComponent('Saved Addresses')}',
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

CustomerAddress? _preferredAddress(List<CustomerAddress> addresses) {
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.isEmpty ? null : addresses.first;
}

String _addressTitle(CustomerAddress address) {
  final label = address.label.trim();
  return label.isEmpty ? 'Deliver to saved address' : 'Deliver to $label';
}

class _BillDetails extends StatelessWidget {
  const _BillDetails({
    required this.total,
    required this.taxes,
    required this.platformFee,
    required this.packagingFee,
    required this.deliveryFee,
    required this.couponDiscount,
    required this.payable,
  });

  final int total;
  final int taxes;
  final int platformFee;
  final int packagingFee;
  final int deliveryFee;
  final int couponDiscount;
  final int payable;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _row('Item total', '₹$total'),
            _row('Taxes', '₹$taxes'),
            _row('Platform fee', '₹$platformFee'),
            _row('Packaging fee', '₹$packagingFee'),
            _row('Delivery fee', '₹$deliveryFee'),
            if (couponDiscount > 0)
              _row(
                'Coupon discount',
                '−₹$couponDiscount',
                valueColor: AppColors.success,
              ),
            const Divider(height: 24),
            _row('To pay', '₹$payable', bold: true),
            if (couponDiscount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'You save ₹$couponDiscount with this order',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({this.instructions = '', super.key});

  final String instructions;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// Mangaale currently settles customer orders in cash on delivery. No payment
  /// gateway is integrated, so this is fixed rather than selectable — showing a
  /// UPI/card choice we cannot actually charge would be misleading.
  static const String _method = 'Cash on Delivery';

  bool _paying = false;

  /// Generated once per checkout screen, not per tap, so a retry after a lost
  /// response resolves to the original order instead of creating a second one.
  final String _idempotencyKey = OrdersRepositoryImpl.newIdempotencyKey();

  /// Places the order via the ViewModel. Navigation only happens on a
  /// confirmed server response — a failure never shows success.
  Future<void> _placeOrder() async {
    setState(() => _paying = true);
    try {
      final grocery = ref.read(cartLinesProvider).first.item.type ==
          CatalogItemType.grocery;
      final result = await ref
          .read(checkoutViewModelProvider.notifier)
          .placeOrder(
            idempotencyKey: _idempotencyKey,
            paymentMethod: grocery ? 'cod' : 'cash',
            instructions: widget.instructions,
          );
      
      if (!mounted) return;
      
      result.when(
        success: (placed) => context.go(
          grocery
              ? '/tracking/${placed.orderId}?mode=grocery'
              : '/tracking/${placed.orderId}',
        ),
        failure: (failure) => _showError(failure.message),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Totals, taxes, fees and round-off come from /customer-web/cart/validate.
    // Nothing on this screen computes money — the button must show exactly what
    // the backend will charge.
    final bill = ref.watch(cartBillProvider);
    final payable = bill.value?.grandTotal ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Select payment method',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          // Only Cash on Delivery is offered: no payment gateway is integrated
          // yet, so offering UPI/card/net-banking would promise a charge the
          // platform cannot take.
          Card(
            color: AppColors.light,
            child: ListTile(
              leading: const Icon(
                Icons.payments_outlined,
                color: AppColors.dark,
              ),
              title: const Text(
                _method,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Pay in cash when your order arrives'),
              trailing: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Online payment is coming soon. For now every order is '
                      'paid in cash on delivery.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(
            label: 'Pay ₹$payable with $_method',
            loading: _paying,
            onPressed: _paying ? null : _placeOrder,
          ),
        ),
      ),
    );
  }
}
