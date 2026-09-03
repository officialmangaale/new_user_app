import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nature/cart_drop/add_to_cart_drop_animation.dart';
import '../../../shared/models/app_models.dart';
import '../../cart/providers/cart_controller.dart';
import '../providers/catalog_providers.dart';
import 'item_customize_sheet.dart';

/// What actually happened when the customer tapped Add.
///
/// Exists so the presentation layer can tell a real cart mutation from a
/// refusal. Only [added] means the cart changed; every other value is a path
/// that deliberately did nothing, and must never produce a splash, a flying
/// drop or a badge bounce.
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
/// ---------------------------------------------------------------------------
/// Nature layer
/// ---------------------------------------------------------------------------
/// This function now reports which branch it took, and fires the water
/// celebration itself. Doing it here rather than in a tap handler is the whole
/// point: this is the only place that knows whether the cart actually changed,
/// so a refusal or a dismissed sheet cannot produce a false success.
///
/// The cart mutation happens first and is never awaited on the animation — the
/// celebration is triggered after the state change, and returns immediately.
///
/// [origin] is optional. It carries the product image the drop is made from and
/// the leaf button it lands on. Callers that omit it still mutate the cart
/// identically and simply get the pot's reaction without the journey.
Future<AddToCartOutcome> addItemToCart(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item, {
  String? restaurantId,
  bool forceCustomise = false,
  ProductAddOrigin? origin,
}) async {
  final controller = ref.read(cartControllerProvider.notifier);
  final storeId = restaurantId ?? item.storeId;

  int currentQuantity() => ref
      .read(cartControllerProvider)
      .quantityForItem(item.id, type: item.type, storeId: storeId);

  // Read before any mutation. Two things come out of it: whether this tap was
  // the ADD button (quantity was zero) or the "+" stepper, and — by reading
  // again afterwards — how many units actually landed in the cart.
  final quantityBefore = currentQuantity();

  /// Runs the water journey. Called only on paths that genuinely mutated the
  /// cart, and only ever after the mutation, so the number of drops is measured
  /// rather than assumed.
  void celebrate() {
    if (!context.mounted) return;
    final unitsAdded = currentQuantity() - quantityBefore;
    if (unitsAdded <= 0) return;
    ref
        .read(cartDropControllerProvider)
        .celebrateAdd(
          context: context,
          item: item,
          unitsAdded: unitsAdded,
          isIncrement: quantityBefore > 0,
          origin: origin,
        );
  }

  if (!item.isAvailable) {
    _notify(context, '${item.name} is unavailable right now.');
    return AddToCartOutcome.unavailable;
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
  if (selection == null) return AddToCartOutcome.cancelled;
  controller.addSelection(selection, restaurantId: storeId);
  celebrate();
  return AddToCartOutcome.added;
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
