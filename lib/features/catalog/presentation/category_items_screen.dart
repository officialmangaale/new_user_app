import '../../cart/presentation/floating_cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/formatting/distance_format.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../app_state/providers/app_controller.dart';
import '../../cart/providers/cart_controller.dart';
import '../domain/restaurant_dish_groups.dart';
import '../providers/catalog_providers.dart';
import 'add_to_cart.dart';
import 'menu/menu_image.dart';
import 'menu/menu_styles.dart';

/// Dishes within one home category, from `/customer-web/categories/:key/items`.
///
/// Food: grouped by restaurant, so tapping "Fries" shows the restaurants that
/// serve fries, each with its fries. Grocery: one flat product grid.
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
      bottomNavigationBar: const CartDock(),
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
        builder: (results) => grocery
            ? _ProductGrid(items: results)
            : _RestaurantGroups(dishes: results, categoryTitle: title),
      ),
    );
  }
}

/// Grocery products: one flat grid, unchanged.
class _ProductGrid extends ConsumerWidget {
  const _ProductGrid({required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 278,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
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
          onAdd: (origin) => addItemToCart(context, ref, item, origin: origin),
          onRemove: () =>
              ref.read(cartControllerProvider.notifier).removeItemById(item.id),
          onTap: () => context.push(
            item.type == CatalogItemType.grocery
                ? '/product/${item.id}'
                : '/food-item/${item.id}',
          ),
        );
      },
    );
  }
}

/// Food categories: the restaurants that serve the dish, each with its dishes
/// from this category. Tapping a restaurant opens its full menu.
class _RestaurantGroups extends StatelessWidget {
  const _RestaurantGroups({required this.dishes, required this.categoryTitle});

  final List<CatalogItem> dishes;
  final String categoryTitle;

  @override
  Widget build(BuildContext context) {
    final groups = groupDishesByRestaurant(dishes);
    final noun = groups.length == 1 ? 'restaurant' : 'restaurants';
    final verb = groups.length == 1 ? 'serves' : 'serve';
    final what = categoryTitle.trim().isEmpty ? 'this' : categoryTitle.trim();
    return ListView.builder(
      key: const Key('category-restaurant-groups'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '${groups.length} $noun $verb $what',
              key: const Key('category-summary'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return _RestaurantSection(group: groups[index - 1]);
      },
    );
  }
}

class _RestaurantSection extends ConsumerWidget {
  const _RestaurantSection({required this.group});

  final RestaurantDishGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = formatDistanceKm(group.distanceKm);
    final meta = [
      if (group.rating != null) '★ ${group.rating!.toStringAsFixed(1)}',
      if (group.deliveryTime.isNotEmpty) group.deliveryTime,
      ?distance,
    ].join(' · ');
    final canOpen = group.storeId.isNotEmpty;
    final subtitle = [
      if (group.isClosed) 'Closed now',
      if (meta.isNotEmpty) meta,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('category-restaurant-${group.key}'),
              onTap: canOpen
                  ? () => context.push('/restaurant/${group.storeId}')
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _RestaurantLogo(name: group.name, url: group.logoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name.isEmpty ? 'Restaurant' : group.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: group.isClosed
                                        ? AppColors.error
                                        : null,
                                    fontWeight: group.isClosed
                                        ? FontWeight.w700
                                        : null,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    if (canOpen) const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 278,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: group.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = group.items[index];
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
                    onAdd: (origin) {
                      if (group.isClosed) {
                        final who = group.name.isEmpty
                            ? 'This restaurant'
                            : group.name;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$who is closed right now.')),
                        );
                        return;
                      }
                      addItemToCart(context, ref, item, origin: origin);
                    },
                    onRemove: () => ref
                        .read(cartControllerProvider.notifier)
                        .removeItemById(item.id),
                    onTap: () => context.push('/food-item/${item.id}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantLogo extends StatelessWidget {
  const _RestaurantLogo({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: url.isEmpty
          ? Text(
              initials.isEmpty ? '·' : initials,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.deepTeal,
              ),
            )
          : MenuImage(url: url, width: 48, height: 48, fit: BoxFit.cover),
    );
  }
}
