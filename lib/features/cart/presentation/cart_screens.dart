import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../shared/models/app_models.dart';
import '../../../core/services/api_exception.dart';
import '../../../shared/repositories/orders_repository.dart';
import '../../app_state/providers/app_controller.dart';
import '../../orders/providers/orders_providers.dart';
import '../../authentication/presentation/auth_screens.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _shared = true;
  bool _couponApplied = false;
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
    final savings = couponDiscount;
    final payable = bill?.grandTotal ?? total;
    return Scaffold(
      appBar: AppBar(
        title: Text(grocery ? 'Your grocery basket' : 'Your food cart'),
        actions: [
          TextButton(
            onPressed: ref.read(appControllerProvider.notifier).clearCart,
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
                      AppPill(
                        label: grocery ? '12 min' : '24 min',
                        icon: Icons.schedule_rounded,
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
          PremiumSurface(
            padding: EdgeInsets.zero,
            child: ListTile(
              minTileHeight: 68,
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              title: Text(
                _couponApplied ? 'WELCOME50 applied' : 'Apply coupon',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _couponApplied ? 'You save ₹50' : 'View available offers',
              ),
              trailing: Icon(
                _couponApplied
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: _couponApplied
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              onTap: () => _showCoupons(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Choose your delivery option',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _CheckoutChoice(
            title: 'Join or create a shared order',
            subtitle: 'Save ₹$savings · 3 nearby users · Adds 8–12 min',
            icon: Icons.people_alt_rounded,
            selected: _shared,
            onTap: () => setState(() => _shared = true),
            badge: 'Best value',
            details: const ['Food: up to 15%', 'Delivery: 50% off'],
          ),
          const SizedBox(height: 10),
          _CheckoutChoice(
            title: 'Order individually',
            subtitle: 'Standard pricing · Normal delivery fee',
            icon: Icons.person_outline_rounded,
            selected: !_shared,
            onTap: () => setState(() => _shared = false),
            details: const ['Faster checkout', 'No group wait'],
          ),
          const SizedBox(height: AppSpacing.lg),
          _AddressCard(grocery: grocery),
          const SizedBox(height: AppSpacing.lg),
          _BillDetails(
            total: total,
            taxes: taxes,
            platformFee: platformFee,
            packagingFee: packagingFee,
            deliveryFee: deliveryFee,
            couponDiscount: couponDiscount,
            sharedSavings: savings,
            payable: payable,
            grocery: grocery,
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
                    if (authenticated) {
                      context.push('/checkout?shared=$_shared');
                    } else {
                      ProtectedActionSheet.show(
                        context,
                        '/checkout?shared=$_shared',
                      );
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

  Future<void> _showCoupons(BuildContext context) async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available coupons',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final coupon in const [
                ('WELCOME50', 'Save ₹50 on your first eligible order'),
                ('FRESH20', '20% off on fresh produce'),
              ])
                Card(
                  child: ListTile(
                    title: Text(
                      coupon.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    subtitle: Text(coupon.$2),
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('APPLY'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && applied == true) {
      setState(() => _couponApplied = true);
    }
  }
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
              Text(
                '₹${line.item.price} each',
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
                  .read(appControllerProvider.notifier)
                  .addItem(line.item),
              onRemove: () => ref
                  .read(appControllerProvider.notifier)
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
                    .read(appControllerProvider.notifier)
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

class _CheckoutChoice extends StatelessWidget {
  const _CheckoutChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.details = const [],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryVeryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: selected
                        ? AppColors.primary
                        : AppColors.background,
                    child: Icon(
                      icon,
                      color: selected
                          ? AppColors.surface
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              AppPill(label: badge!),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final detail in details)
                        AppPill(
                          label: detail,
                          icon: Icons.check_rounded,
                          background: selected
                              ? AppColors.primaryLight
                              : AppColors.background,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.grocery});

  final bool grocery;

  @override
  Widget build(BuildContext context) {
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
                      const Text(
                        'Deliver to Home',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '12, 4th Main Road, Indiranagar',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Change')),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    grocery
                        ? 'Delivery in 12–15 minutes'
                        : 'Delivery by 8:12 PM',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillDetails extends StatelessWidget {
  const _BillDetails({
    required this.total,
    required this.taxes,
    required this.platformFee,
    required this.packagingFee,
    required this.deliveryFee,
    required this.couponDiscount,
    required this.sharedSavings,
    required this.payable,
    required this.grocery,
  });

  final int total;
  final int taxes;
  final int platformFee;
  final int packagingFee;
  final int deliveryFee;
  final int couponDiscount;
  final int sharedSavings;
  final int payable;
  final bool grocery;

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
            if (sharedSavings > 0)
              _row(
                grocery ? 'Share Basket saving' : 'FoodShare saving',
                '−₹$sharedSavings',
                valueColor: AppColors.success,
              ),
            _row('Wallet balance applied', '₹0'),
            const Divider(height: 24),
            _row('To pay', '₹$payable', bold: true),
            if (sharedSavings + couponDiscount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'You save ₹${sharedSavings + couponDiscount} with '
                  '${grocery ? 'Share Basket' : 'FoodShare'}',
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
  const CheckoutScreen({required this.shared, super.key});

  final bool shared;

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
  final String _idempotencyKey = OrdersRepository.newIdempotencyKey();

  /// Places the order against restaurant-service. Navigation only happens on a
  /// confirmed server response — a failure never shows success.
  Future<void> _placeOrder() async {
    final state = ref.read(appControllerProvider);
    final lines = ref.read(cartLinesProvider);

    if (lines.isEmpty) {
      _showError('Your cart is empty.');
      return;
    }
    if (state.cartRestaurantId.isEmpty) {
      _showError(
        'We could not tell which restaurant this cart belongs to. '
        'Please reopen the restaurant and add items again.',
      );
      return;
    }

    setState(() => _paying = true);
    try {
      final placed = await ref
          .read(ordersRepositoryProvider)
          .placeOrder(
            restaurantId: state.cartRestaurantId,
            lines: lines,
            idempotencyKey: _idempotencyKey,
            paymentMethod: 'cod',
          );
      ref.read(appControllerProvider.notifier).clearCart();
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      context.go('/tracking/${placed.orderId}');
    } on ApiException catch (error) {
      _showError(error.message);
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
          if (widget.shared)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.light,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: AppColors.dark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You’re saving ₹${bill.value?.discount ?? 0} with a shared order',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
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
