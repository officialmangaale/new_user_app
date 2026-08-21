import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../cart/providers/cart_controller.dart';
import 'item_customize_sheet.dart';

/// Single entry point for adding an item to the cart.
///
/// Items without options are added directly. Items with variants or addons open
/// the customise sheet first, so a size or extra is never silently dropped.
/// Tapping "+" on an item already in the cart repeats its last configuration
/// rather than re-asking.
Future<void> addItemToCart(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item, {
  String? restaurantId,
  bool forceCustomise = false,
}) async {
  final controller = ref.read(cartControllerProvider.notifier);
  final storeId = restaurantId ?? item.storeId;

  if (!item.needsCustomisation) {
    controller.addItem(item, restaurantId: storeId);
    return;
  }

  if (!forceCustomise &&
      controller.addOrRepeat(item.id, restaurantId: storeId)) {
    return;
  }

  final selection = await showItemCustomizeSheet(context, item);
  if (selection == null) return;
  controller.addSelection(selection, restaurantId: storeId);
}
