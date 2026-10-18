import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';

import '../../../core/widgets/app_ui.dart';
import '../../../core/error/failures.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../account/address/address_form_logic.dart';
import '../../account/address/address_form_sheet.dart';
import '../../account/address/address_location_capture.dart';
import '../../account/address/address_providers.dart';
import '../../orders/data/repositories/orders_repository_impl.dart';
import '../../app_state/providers/app_controller.dart';
import '../../orders/providers/live_orders_provider.dart';
import '../../orders/providers/orders_providers.dart';
import '../../authentication/presentation/auth_screens.dart';
import '../../app_state/providers/location_providers.dart';
import '../../location/presentation/delivery_location_sheet.dart';
import '../providers/cart_controller.dart';
import 'complete_delivery_address_sheet.dart';
import 'customer_name_sheet.dart';
import '../providers/checkout_view_model.dart';
import '../providers/delivery_location.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({this.onClose, super.key});

  final VoidCallback? onClose;

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

    final quote = ref.watch(cartBillProvider);
    final bill = !quote.isLoading && !quote.hasError ? quote.value : null;
    final deliveryBlocked = quote.hasError &&
        (quote.error is DeliveryPricingFailure ||
            quote.error is DeliveryLocationRequired);
    final payable = bill?.valid == true
        ? '₹${formatMoney(bill!.grandTotal)}'
        : quote.isLoading
        ? 'Calculating…'
        : deliveryBlocked
        ? 'Delivery unavailable'
        : 'Price unavailable';
    final footnote = bill?.valid == true
        ? 'Including taxes'
        : deliveryBlocked
        ? 'Items ₹${ref.watch(cartTotalProvider)} at menu prices'
        : 'Including taxes';
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose == null
            ? null
            : IconButton(
                tooltip: 'Close cart',
                onPressed: widget.onClose,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
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
                  for (var i = 0; i < lines.length; i++) ...[
                    _CartLineTile(
                      line: lines[i],
                      price: grocery
                          ? bill?.items
                                .where(
                                  (item) => item.itemId == lines[i].item.id,
                                )
                                .firstOrNull
                          : bill != null &&
                                bill.items.length == lines.length &&
                                bill.items[i].itemId == lines[i].item.id
                          ? bill.items[i]
                          : null,
                      pricing: quote,
                    ),
                    if (i != lines.length - 1) const Divider(height: 24),
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
          if (!grocery) const _CouponEntry(),
          const _BillDetails(),
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
                      payable,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      footnote,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppButton(
                  label: widget.onClose == null
                      ? 'Proceed to checkout'
                      : 'Checkout',
                  onPressed: bill?.valid != true
                      ? null
                      : () {
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
  const _CartLineTile({required this.line, this.price, this.pricing});

  final CartLine line;
  final BillItem? price;

  /// The cart bill's state. A failed bill is not "updating": the line shows
  /// its menu price instead of an endless spinner-style caption.
  final AsyncValue<BillSummary>? pricing;

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
                price != null
                    ? '₹${formatMoney(price!.sellingPrice)} each'
                    : pricing?.hasError == true
                    ? 'Menu price ₹${line.item.price}'
                    : 'Updating price…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (price?.originalPrice != null)
                Text(
                  '₹${formatMoney(price!.originalPrice!)}',
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              if ((price?.discount ?? 0) > 0)
                Text(
                  'Save ₹${formatMoney(price!.discount)} each',
                  style: const TextStyle(color: AppColors.success),
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
                  .addSelection(line.selection),
              onRemove: () => ref
                  .read(cartControllerProvider.notifier)
                  .removeItem(line.lineId),
            ),
            const SizedBox(height: 5),
            Text(
              price != null
                  ? '₹${formatMoney(price!.lineTotal)}'
                  : pricing?.hasError == true
                  ? '₹${line.total}'
                  : '—',
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

/// The delivery location, described from the one canonical selection that also
/// drives restaurant distances and the bill. It never reads the address book on
/// its own, so it cannot disagree with the price below it.
class _AddressCard extends ConsumerWidget {
  const _AddressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(deliveryLocationViewProvider);
    final theme = Theme.of(context);

    late final String title;
    late final String subtitle;
    late final IconData icon;
    switch (view.phase) {
      case DeliveryLocationPhase.locating:
        icon = Icons.my_location_rounded;
        title = 'Delivery location';
        subtitle = 'Finding your location…';
      case DeliveryLocationPhase.unavailable:
        icon = Icons.location_off_outlined;
        title = 'Choose delivery location';
        subtitle =
            'Use your current location or add an address to see delivery charges.';
      case DeliveryLocationPhase.needsConfirmation:
        icon = Icons.home_rounded;
        title = _addressTitle(view.address!);
        subtitle = view.address!.singleLine.isEmpty
            ? 'Confirm your delivery location'
            : view.address!.singleLine;
      case DeliveryLocationPhase.ready:
        if (view.isCurrentLocation) {
          icon = Icons.my_location_rounded;
          title = 'Deliver to current location';
          subtitle = view.addressPending
              ? 'Finding your area…'
              : [view.primary, view.secondary]
                    .where((part) => part.trim().isNotEmpty)
                    .join(', ');
        } else {
          icon = Icons.home_rounded;
          final label = view.location!.label.trim();
          title = label.isEmpty ? 'Deliver to saved address' : 'Deliver to $label';
          subtitle = view.location!.formattedAddress.isEmpty
              ? 'Saved address'
              : view.location!.formattedAddress;
        }
    }
    final needsConfirmation =
        view.phase == DeliveryLocationPhase.needsConfirmation;
    final unavailable = view.phase == DeliveryLocationPhase.unavailable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: const Key('address-card-title'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        key: const Key('address-card-subtitle'),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (needsConfirmation)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Location confirmation required',
                            key: Key('address-needs-confirmation'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (view.isCurrentLocation)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Add your house or flat before placing the order.',
                            key: const Key('address-needs-door-details'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('checkout-address-action'),
                  onPressed: () => showDeliveryLocationSheet(context),
                  child: Text(unavailable ? 'Choose' : 'Change'),
                ),
              ],
            ),
            if (needsConfirmation)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    key: const Key('address-use-current-location'),
                    onPressed: () => confirmAddressWithCurrentLocation(
                      context,
                      ref,
                      view.address!,
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Use current location'),
                  ),
                ),
              ),
            if (view.isCurrentLocation)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    key: const Key('address-complete-details'),
                    onPressed: () => _completeDeliveryDetails(context, ref),
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: const Text('Add house / flat details'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the door details and saves the current location as an address.
/// Returns whether an address was saved.
Future<bool> _completeDeliveryDetails(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showCompleteDeliveryAddressSheet(context);
  if (saved == null) return false;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Delivering to ${saved.label.isEmpty ? 'this address' : saved.label}',
      ),
    ),
  );
  return true;
}

/// Adds an address without leaving checkout. "Deliver my orders here" is on
/// by default, so the saved address becomes the default, which is the address
/// checkout places the order against.
Future<void> _addAddressFromCheckout(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showAddressFormSheet(context);
  if (saved == null) return;
  ref.read(useCurrentLocationProvider.notifier).choose(false);
  ref.invalidate(addressesProvider);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        saved.isDefault
            ? 'Delivering to ${saved.label.isEmpty ? 'this address' : saved.label}'
            : 'Address saved',
      ),
    ),
  );
}

String _addressTitle(CustomerAddress address) {
  final label = address.label.trim();
  return label.isEmpty ? 'Deliver to saved address' : 'Deliver to $label';
}

class _BillDetails extends ConsumerWidget {
  const _BillDetails();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(cartBillProvider);
    if (quote.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Calculating delivery and taxes…'),
      );
    }
    final bill = quote.hasError ? null : quote.value;
    if (bill == null || !bill.valid) {
      return _PricingProblemCard(
        error: quote.error,
        billMessage: bill?.message ?? '',
      );
    }
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
            _row('Item total', bill.subtotal),
            if (bill.deliveryFee > 0) _row('Delivery fee', bill.deliveryFee),
            if (bill.platformFee > 0) _row('Platform fee', bill.platformFee),
            if (bill.packagingCharge > 0)
              _row('Packaging fee', bill.packagingCharge),
            if (bill.additionalCharges > 0)
              _row('Additional charges', bill.additionalCharges),
            for (final fee in bill.fees)
              if (fee.amount > 0) _row(fee.title, fee.amount),
            if (bill.discount > 0)
              _row('Coupon discount', bill.discount, discount: true),
            if (bill.offerDiscount > 0)
              _row('Offer discount', bill.offerDiscount, discount: true),
            if (bill.cgst > 0) _row('CGST', bill.cgst),
            if (bill.sgst > 0) _row('SGST', bill.sgst),
            if (bill.taxAmount > 0 && bill.cgst <= 0 && bill.sgst <= 0)
              _row('Taxes', bill.taxAmount),
            if (bill.tipAmount > 0) _row('Tip', bill.tipAmount),
            if (bill.roundOff != 0) _row('Round off', bill.roundOff),
            const Divider(),
            _row('To pay', bill.grandTotal),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, double amount, {bool discount = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(title)),
        Text('${discount ? '−' : ''}₹${formatMoney(amount)}'),
      ],
    ),
  );
}

class _CouponEntry extends ConsumerStatefulWidget {
  const _CouponEntry();
  @override
  ConsumerState<_CouponEntry> createState() => _CouponEntryState();
}

class _CouponEntryState extends ConsumerState<_CouponEntry> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(cartCouponProvider);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Coupon code'),
          ),
        ),
        TextButton(
          onPressed: () =>
              ref.read(cartCouponProvider.notifier).setCode(controller.text),
          child: const Text('Apply'),
        ),
        if (applied.isNotEmpty)
          TextButton(
            onPressed: () {
              controller.clear();
              ref.read(cartCouponProvider.notifier).setCode('');
            },
            child: const Text('Remove'),
          ),
      ],
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
    // Re-entrancy guard. `onPressed` is already nulled while `_paying` is true,
    // but that only takes effect on the next rebuild — a fast double-tap can
    // land twice before the frame renders. The idempotency key would make the
    // second order a no-op server-side; this stops it leaving the device.
    if (_paying) return;
    final quote = ref.read(cartBillProvider);
    if (quote.isLoading || quote.hasError || quote.value?.valid != true) return;

    final lines = ref.read(cartLinesProvider);
    if (lines.isEmpty) {
      // `lines.first` below would otherwise throw a bare StateError.
      _showError('Your cart is empty.');
      return;
    }
    final grocery = lines.first.item.type == CatalogItemType.grocery;

    // Orders carry the customer's name. Phone sign-up never asks for it, so ask
    // here, in one field, instead of failing with a message that tells the
    // customer to go and find a profile screen.
    if ((await readKnownCustomerName(ref)).isEmpty) {
      if (!mounted) return;
      final name = await showCustomerNameSheet(context);
      if (name == null) return;
    }
    if (!mounted) return;

    // Delivery was priced from the current location, which carries no house or
    // flat. Ask for exactly that - and nothing already known - before the
    // order goes out. The saved address keeps the same coordinates.
    if (ref.read(deliveryLocationViewProvider).needsDoorDetails) {
      final saved = await showCompleteDeliveryAddressSheet(context);
      if (saved == null || !mounted) return;
      // The address book changed, so the location and bill are recomputing.
      try {
        await ref.read(cartBillProvider.future);
      } catch (_) {
        // Surfaced by the readiness check below.
      }
      if (!mounted) return;
      final refreshed = ref.read(cartBillProvider);
      if (refreshed.isLoading ||
          refreshed.hasError ||
          refreshed.value?.valid != true) {
        _showError('Please review the updated bill and try again.');
        return;
      }
    }

    setState(() => _paying = true);
    try {
      final result = await ref
          .read(checkoutViewModelProvider.notifier)
          .placeOrder(
            idempotencyKey: _idempotencyKey,
            paymentMethod: grocery ? 'cod' : 'cash',
            instructions: widget.instructions,
          );

      if (!mounted) return;

      result.when(
        success: (placed) {
          final router = GoRouter.of(context);
          final tracking = grocery
              ? '/tracking/${placed.orderId}?mode=grocery'
              : '/tracking/${placed.orderId}';
          // Home goes underneath tracking, so Back from tracking lands on Home
          // (with the live-order banner) instead of leaving the app, and the
          // new order shows up there straight away.
          ref.invalidate(liveOrdersProvider);
          ref.invalidate(activeOrdersProvider);
          router.go('/home');
          router.push<void>(tracking);
        },
        failure: (failure) {
          _showError(failure.message);
          ref.invalidate(cartBillProvider);
        },
      );
    } catch (error, stackTrace) {
      // Nothing below the ViewModel is allowed to fail silently. Anything that
      // is not a mapped Failure — a plugin error, a disposed provider, a parse
      // bug — still has to reach the customer as a visible message, otherwise
      // the button looks dead.
      debugPrint('Checkout failed: $error');
      debugPrintStack(stackTrace: stackTrace, label: 'Checkout');
      _showError('Could not place your order. Please try again.');
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
    final ready =
        !bill.isLoading && !bill.hasError && bill.value?.valid == true;
    final payable = ready ? formatMoney(bill.value!.grandTotal) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _AddressCard(),
          const _BillDetails(),
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
            label: ready
                ? 'Pay ₹$payable with $_method'
                : 'Waiting for confirmed prices',
            loading: _paying,
            onPressed: _paying || !ready ? null : _placeOrder,
          ),
        ),
      ),
    );
  }
}
/// Shown when the bill cannot be priced. The message and the offered fixes
/// follow the typed reason, so a valid address is never blamed for a
/// restaurant-side or delivery-area problem.
class _PricingProblemCard extends ConsumerWidget {
  const _PricingProblemCard({required this.error, required this.billMessage});

  final Object? error;
  final String billMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = this.error;
    String message;
    CustomerAddress? confirmAddress;
    var addressActions = false;
    var needsAddress = false;
    if (error is DeliveryLocationRequired) {
      message = error.address == null
          ? error.message
          : '${error.message} This saved address has no map location yet.';
      confirmAddress = error.address;
      addressActions = true;
      needsAddress = error.address == null;
    } else if (error is DeliveryPricingFailure) {
      message = error.message;
      addressActions = error.status.addressCanFix;
    } else if (billMessage.isNotEmpty) {
      message = billMessage;
    } else if (error is Failure) {
      message = error.message;
    } else if (error is StateError) {
      message = error.message.toString();
    } else {
      message = 'Unable to confirm prices. Please try again.';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    key: const Key('pricing-problem-message'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (confirmAddress != null)
                  FilledButton.icon(
                    key: const Key('pricing-use-current-location'),
                    onPressed: () => confirmAddressWithCurrentLocation(
                      context,
                      ref,
                      confirmAddress!,
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Use current location'),
                  ),
                if (addressActions && !needsAddress)
                  OutlinedButton(
                    key: const Key('pricing-change-address'),
                    onPressed: () => context.push('/addresses'),
                    child: const Text('Change address'),
                  ),
                if (needsAddress)
                  FilledButton.icon(
                    key: const Key('pricing-choose-location'),
                    onPressed: () => showDeliveryLocationSheet(context),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Choose location'),
                  ),
                if (needsAddress)
                  OutlinedButton(
                    key: const Key('pricing-add-address'),
                    onPressed: () => _addAddressFromCheckout(context, ref),
                    child: const Text('Add address'),
                  ),
                TextButton(
                  key: const Key('pricing-retry'),
                  onPressed: () {
                    // Re-read the address book and the selection, then price
                    // again from the CURRENT canonical coordinates - never a
                    // stale address object or an old GPS fix.
                    ref.invalidate(addressesProvider);
                    ref.invalidate(deliveryLocationProvider);
                    ref.invalidate(cartBillProvider);
                  },
                  child: const Text('Retry pricing'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Saves the device's current position as the pin of a saved address, after
/// the customer confirms. Used to recover legacy addresses that were saved as
/// text only. The typed address is kept exactly as it was.
Future<void> confirmAddressWithCurrentLocation(
  BuildContext context,
  WidgetRef ref,
  CustomerAddress address,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Use your current location?'),
      content: Text(
        'We will save where you are right now as the delivery location for '
        '${address.label.trim().isEmpty ? 'this address' : address.label.trim()}. '
        'Only continue if you are at this address.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Use current location'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final result = await ref.read(addressLocationCaptureProvider).capture();
  final captured = result.location;
  if (captured == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (result.failure) {
          LocationCaptureFailure.serviceDisabled => AddressCopy.gpsOff,
          LocationCaptureFailure.permissionDenied => AddressCopy.locationDenied,
          LocationCaptureFailure.permissionDeniedForever =>
            AddressCopy.locationDeniedForever,
          _ => AddressCopy.locationUnavailable,
        }),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  try {
    await ref
        .read(accountRepositoryProvider)
        .updateAddress(
          address.id,
          address.withPin(
            latitude: captured.latitude,
            longitude: captured.longitude,
            accuracyMeters: captured.accuracyMeters,
          ),
        );
    if (!context.mounted) return;
    // The address book is the source of the delivery location, so this alone
    // re-prices the cart.
    ref.invalidate(addressesProvider);
    messenger.showSnackBar(
      const SnackBar(content: Text('Delivery location confirmed.')),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'We could not save the location. Please try again.',
        ),
      ),
    );
  }
}
