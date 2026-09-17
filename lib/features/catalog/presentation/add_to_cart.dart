import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/cart/presentation/product_cart_animation.dart';
import '../../../shared/models/app_models.dart';
import '../../cart/providers/cart_controller.dart';
import '../providers/catalog_providers.dart';
import 'item_customize_sheet.dart';

/// What actually happened when the customer tapped Add.
///
/// Exists so the presentation layer can tell a real cart mutation from a
/// refusal. Only [added] means the cart changed; every other value is a path
/// that deliberately did nothing, and must never produce a success animation.
enum AddToCartOutcome {
  /// The cart was mutated.
  added,

  /// The item is not available right now. The customer has been told.
  unavailable,

  /// The item needed variants or add-ons and they could not be fetched.
  /// The customer has been told.
  optionsUnavailable,

  /// The customise sheet opened and the customer dismissed it.
  cancelled;

  /// True only when the cart genuinely changed.
  bool get didMutateCart => this == AddToCartOutcome.added;
}

// Only option dialogs are guarded. Ordinary repeated adds remain synchronous
// so every tap increments the existing cart exactly once.
final _pendingOptionsProvider = Provider<Set<String>>((ref) => <String>{});

/// Single entry point for adding an item to the cart.
///
/// Items without options are added directly. Items with variants or addons open
/// the customise sheet first, so a size or extra is never silently dropped.
/// Tapping "+" on an item already in the cart repeats its last configuration
/// rather than re-asking.
///
/// List endpoints do not all ship the option arrays — `/customer-web/search`
/// never does, and some category rows omit them — but they do set
/// `has_variants` / `has_addons`. When an item says it needs a choice but
/// arrived without one, the full record is fetched from
/// `/customer-web/catalog/items/:id` before the sheet opens. Without this the
/// item is added at its base price, which for a variant-priced dish is ₹0.
///
/// Visual feedback follows the completed local cart mutation.
Future<AddToCartOutcome> addItemToCart(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item, {
  String? restaurantId,
  bool forceCustomise = false,
  ProductAddOrigin? origin,
}) async {
  final controller = ref.read(cartControllerProvider.notifier);
  final route = ModalRoute.of(context);
  final storeId = restaurantId ?? item.storeId;

  int currentQuantity() => ref
      .read(cartControllerProvider)
      .quantityForItem(item.id, type: item.type, storeId: storeId);

  // Read before any mutation. Two things come out of it: whether this tap was
  // the ADD button (quantity was zero) or the "+" stepper, and — by reading
  // again afterwards — how many units actually landed in the cart.
  final quantityBefore = currentQuantity();

  // Feedback never controls the cart mutation.
  void celebrate() {
    if (!context.mounted) return;
    final unitsAdded = currentQuantity() - quantityBefore;
    if (unitsAdded <= 0) return;
    ref
        .read(productCartAnimationProvider)
        .celebrateAdd(
          context: context,
          item: item,
          unitsAdded: unitsAdded,
          cartCountAfter: ref.read(cartCountProvider),
          isIncrement: quantityBefore > 0,
          origin: origin,
        );
  }

  if (!item.isAvailable) {
    _notify(context, '${item.name} is unavailable right now.');
    return AddToCartOutcome.unavailable;
  }

  // Grocery lists mix products from several shops, but an order comes from
  // one shop. Adding another shop's product empties the grocery cart, so ask
  // first. The check is synchronous, so ordinary adds stay synchronous.
  if (_switchesGroceryShop(ref, item, storeId)) {
    final replace = await _confirmGroceryShopSwitch(context, ref, item);
    if (!replace || !context.mounted) return AddToCartOutcome.cancelled;
  }

  if (!item.needsCustomisation) {
    controller.addItem(item, restaurantId: storeId);
    celebrate();
    return AddToCartOutcome.added;
  }

  if (!forceCustomise &&
      controller.addOrRepeat(item.id, restaurantId: storeId)) {
    celebrate();
    return AddToCartOutcome.added;
  }

  final pending = ref.read(_pendingOptionsProvider);
  final requestKey = '${item.type.name}:$storeId:${item.id}';
  if (!pending.add(requestKey)) return AddToCartOutcome.cancelled;
  try {
    var resolved = item;
    if (item.needsOptionHydration && item.type == CatalogItemType.food) {
      try {
        resolved = await ref.read(itemDetailProvider(item.id).future);
      } catch (_) {
        if (!context.mounted) return AddToCartOutcome.optionsUnavailable;
        _notify(context, 'Could not load options for ${item.name}.');
        return AddToCartOutcome.optionsUnavailable;
      }
      if (!context.mounted) return AddToCartOutcome.optionsUnavailable;
      if (route?.isCurrent == false) return AddToCartOutcome.cancelled;
      if (!resolved.isAvailable) {
        _notify(context, '${resolved.name} is unavailable right now.');
        return AddToCartOutcome.unavailable;
      }
      // The detail endpoint may report no options after all; add it directly
      // rather than showing an empty sheet.
      if (resolved.variants.isEmpty && resolved.addons.isEmpty) {
        controller.addItem(resolved, restaurantId: storeId);
        celebrate();
        return AddToCartOutcome.added;
      }
    }

    if (!context.mounted) return AddToCartOutcome.cancelled;
    final selection = await showItemCustomizeSheet(context, resolved);
    if (selection == null || !context.mounted) {
      return AddToCartOutcome.cancelled;
    }
    controller.addSelection(selection, restaurantId: storeId);
    celebrate();
    return AddToCartOutcome.added;
  } finally {
    pending.remove(requestKey);
  }
}

/// True when adding [item] would empty a grocery cart holding another shop's
/// products.
bool _switchesGroceryShop(WidgetRef ref, CatalogItem item, String storeId) {
  if (item.type != CatalogItemType.grocery || storeId.isEmpty) return false;
  final cart = ref.read(cartControllerProvider);
  return cart.groceryCart.isNotEmpty &&
      cart.cartGroceryMerchantId.isNotEmpty &&
      cart.cartGroceryMerchantId != storeId;
}

Future<bool> _confirmGroceryShopSwitch(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item,
) async {
  final cart = ref.read(cartControllerProvider);
  final currentShop = cart.groceryCart.keys
      .map((lineId) => cart.knownItems[lineId]?.item.store ?? '')
      .firstWhere((name) => name.isNotEmpty, orElse: () => '');
  final from = currentShop.isEmpty ? 'another shop' : currentShop;
  final newShop = item.store.isEmpty ? 'a different shop' : item.store;
  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Replace your grocery cart?'),
      content: Text(
        'Your cart has items from $from. A grocery order comes from one shop, '
        'so adding ${item.name} from $newShop will remove them.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('grocery_shop_switch_keep'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep cart'),
        ),
        FilledButton(
          key: const ValueKey('grocery_shop_switch_replace'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return replace ?? false;
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
