import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../cart/providers/cart_controller.dart';
import '../providers/catalog_providers.dart';
import 'item_customize_sheet.dart';

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
Future<void> addItemToCart(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item, {
  String? restaurantId,
  bool forceCustomise = false,
}) async {
  final controller = ref.read(cartControllerProvider.notifier);
  final storeId = restaurantId ?? item.storeId;

  if (!item.isAvailable) {
    _notify(context, '${item.name} is unavailable right now.');
    return;
  }

  if (!item.needsCustomisation) {
    controller.addItem(item, restaurantId: storeId);
    return;
  }

  if (!forceCustomise &&
      controller.addOrRepeat(item.id, restaurantId: storeId)) {
    return;
  }

  var resolved = item;
  if (item.needsOptionHydration && item.type == CatalogItemType.food) {
    try {
      resolved = await ref.read(itemDetailProvider(item.id).future);
    } catch (_) {
      if (!context.mounted) return;
      _notify(context, 'Could not load options for ${item.name}.');
      return;
    }
    if (!context.mounted) return;
    if (!resolved.isAvailable) {
      _notify(context, '${resolved.name} is unavailable right now.');
      return;
    }
    // The detail endpoint may report no options after all; add it directly
    // rather than showing an empty sheet.
    if (resolved.variants.isEmpty && resolved.addons.isEmpty) {
      controller.addItem(resolved, restaurantId: storeId);
      return;
    }
  }

  if (!context.mounted) return;
  final selection = await showItemCustomizeSheet(context, resolved);
  if (selection == null) return;
  controller.addSelection(selection, restaurantId: storeId);
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
