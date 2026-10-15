import '../../cart/presentation/floating_cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../features/cart/presentation/product_cart_animation.dart';
import '../../../core/widgets/app_ui.dart';
import '../../cart/providers/cart_controller.dart';
import '../providers/catalog_providers.dart';
import 'add_to_cart.dart';

export 'menu/restaurant_menu_screen.dart' show RestaurantDetailsScreen;

class FoodItemDetailsScreen extends ConsumerStatefulWidget {
  const FoodItemDetailsScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<FoodItemDetailsScreen> createState() =>
      _FoodItemDetailsScreenState();
}

class _FoodItemDetailsScreenState extends ConsumerState<FoodItemDetailsScreen> {
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemDetailProvider(widget.itemId));

    return itemAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text(
            'Could not load item.',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (item) {
        final quantity = ref.watch(
          cartControllerProvider.select(
            (state) => state.quantityForItem(
              item.id,
              type: item.type,
              storeId: item.storeId,
            ),
          ),
        );
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                expandedHeight: 330,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: AppNetworkImage(
                    key: _imageKey,
                    url: item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                actions: [
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.isVeg ? Icons.eco_rounded : Icons.circle,
                          color: item.isVeg
                              ? AppColors.success
                              : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          item.isVeg ? 'Vegetarian' : 'Non-vegetarian',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '₹${item.price}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 9),
                    if (item.subtitle.isNotEmpty) ...[
                      Text(item.subtitle),
                      const SizedBox(height: 18),
                    ],
                    if (item.variants.isNotEmpty) ...[
                      Text(
                        'Available sizes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            for (final variant in item.variants)
                              ListTile(
                                title: Text(variant.name),
                                trailing: Text('₹${variant.price}'),
                                enabled: variant.isAvailable,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                    if (item.addons.isNotEmpty) ...[
                      Text(
                        'Add-ons',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            for (final addon in item.addons)
                              ListTile(
                                title: Text(addon.name),
                                trailing: Text('+₹${addon.price}'),
                                enabled: addon.isAvailable,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: CartDock(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    QuantityControl(
                      quantity: quantity,
                      addButtonKey: _addKey,
                      onAdd: () => addItemToCart(
                        context,
                        ref,
                        item,
                        origin: ProductAddOrigin(
                          imageKey: _imageKey,
                          addButtonKey: _addKey,
                        ),
                      ),
                      onRemove: () => ref
                          .read(cartControllerProvider.notifier)
                          .removeItemById(item.id),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: quantity == 0
                            ? 'Add to cart • ₹${item.price}'
                            : 'View cart • ₹${ref.watch(cartTotalProvider)}',
                        onPressed: quantity == 0
                            ? () => addItemToCart(
                                context,
                                ref,
                                item,
                                forceCustomise: true,
                                origin: ProductAddOrigin(
                                  imageKey: _imageKey,
                                  addButtonKey: _addKey,
                                ),
                              )
                            : () => context.push('/cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GroceryProductDetailsScreen extends ConsumerStatefulWidget {
  const GroceryProductDetailsScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<GroceryProductDetailsScreen> createState() =>
      _GroceryProductDetailsScreenState();
}

class _GroceryProductDetailsScreenState
    extends ConsumerState<GroceryProductDetailsScreen> {
  int _page = 0;
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(groceryProductDetailProvider(widget.itemId));

    return itemAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => const Scaffold(
        body: Center(
          child: Text(
            'Could not load item.',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (item) {
        final quantity = ref.watch(
          cartControllerProvider.select(
            (state) => state.quantityForItem(
              item.id,
              type: item.type,
              storeId: item.storeId,
            ),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Product details'),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              SizedBox(
                key: _imageKey,
                height: 300,
                child: PageView.builder(
                  itemCount: 3,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: AppNetworkImage(
                      url: item.imageUrl,
                      fit: BoxFit.contain,
                      borderRadius: 22,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _page ? 20 : 7,
                    height: 7,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'FRESHCART SELECT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.dark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(item.subtitle),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '₹${item.price}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${item.originalPrice}',
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppPill(
                    label: '${item.discountPercent}% off',
                    background: const Color(0xFFEAF8EF),
                    foreground: const Color(0xFF137333),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.light,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.dark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.store.isEmpty
                                ? 'Available from selected store'
                                : 'Available from ${item.store}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    Row(
                      children: [
                        const Expanded(child: Text('Normal price')),
                        Text(
                          '₹${item.price}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Expanded(child: Text('Share Basket price')),
                        Text(
                          '₹${item.price - (item.price * item.sharedDiscount ~/ 100)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _InfoExpansion(
                title: 'Product description',
                body:
                    'Freshly sourced and quality checked before dispatch. Store in a cool, dry place and consume within the recommended period.',
              ),
              const _InfoExpansion(
                title: 'Ingredients',
                body:
                    'Made from responsibly sourced ingredients. See packaging for allergen and batch-specific information.',
              ),
              const _InfoExpansion(
                title: 'Nutritional information',
                body:
                    'Energy 128 kcal • Protein 4 g • Carbohydrate 22 g • Fat 3 g per serving.',
              ),
            ],
          ),
          bottomNavigationBar: CartDock(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    QuantityControl(
                      quantity: quantity,
                      addButtonKey: _addKey,
                      onAdd: () => addItemToCart(
                        context,
                        ref,
                        item,
                        origin: ProductAddOrigin(
                          imageKey: _imageKey,
                          addButtonKey: _addKey,
                        ),
                      ),
                      onRemove: () => ref
                          .read(cartControllerProvider.notifier)
                          .removeItemById(item.id),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: quantity == 0
                            ? 'Add to basket • ₹${item.price}'
                            : 'View basket • ₹${ref.watch(cartTotalProvider)}',
                        onPressed: quantity == 0
                            ? () => addItemToCart(
                                context,
                                ref,
                                item,
                                forceCustomise: true,
                                origin: ProductAddOrigin(
                                  imageKey: _imageKey,
                                  addButtonKey: _addKey,
                                ),
                              )
                            : () => context.push('/cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoExpansion extends StatelessWidget {
  const _InfoExpansion({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(body)),
      ],
    );
  }
}
