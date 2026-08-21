import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../app_state/providers/app_controller.dart';
import '../../cart/providers/cart_controller.dart';
import '../providers/catalog_providers.dart';
import 'add_to_cart.dart';

/// Dishes within one home category, from `/customer-web/categories/:key/items`.
class CategoryItemsScreen extends ConsumerWidget {
  const CategoryItemsScreen({
    required this.categoryKey,
    this.title = '',
    super.key,
  });

  final String categoryKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grocery =
        ref.watch(appControllerProvider).mode == DeliveryMode.grocery;
    final items = grocery
        ? ref.watch(groceryCategoryItemsProvider(categoryKey))
        : ref.watch(categoryItemsProvider(categoryKey));
    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Category' : title)),
      body: AsyncListView(
        value: items,
        onRetry: () {
          if (grocery) {
            ref.invalidate(groceryCategoryItemsProvider(categoryKey));
          } else {
            ref.invalidate(categoryItemsProvider(categoryKey));
          }
        },
        empty: EmptyState(
          icon: grocery
              ? Icons.local_grocery_store_outlined
              : Icons.no_meals_rounded,
          title: 'Nothing here yet',
          message: grocery
              ? 'No grocery products are available in this category near you.'
              : 'No dishes are available in this category near you.',
        ),
        builder: (results) => GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 278,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            return ProductCard(
              item: item,
              quantity: ref.watch(
                cartControllerProvider.select(
                  (state) => state.quantityForItem(
                    item.id,
                    type: item.type,
                    storeId: item.storeId,
                  ),
                ),
              ),
              onAdd: () => addItemToCart(context, ref, item),
              onRemove: () =>
                  ref.read(cartControllerProvider.notifier).removeItemById(item.id),
              onTap: () => context.push(
                item.type == CatalogItemType.grocery
                    ? '/product/${item.id}'
                    : '/food-item/${item.id}',
              ),
            );
          },
        ),
      ),
    );
  }
}
