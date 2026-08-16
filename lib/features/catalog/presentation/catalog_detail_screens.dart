import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../shared/mock_data/mock_data.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../../shared/repositories/catalog_repository.dart';
import '../../app_state/providers/app_controller.dart';
import '../providers/catalog_providers.dart';

class RestaurantDetailsScreen extends ConsumerStatefulWidget {
  const RestaurantDetailsScreen({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  ConsumerState<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState
    extends ConsumerState<RestaurantDetailsScreen> {
  bool _vegOnly = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Detail and menu are separate endpoints; the header renders as soon as the
    // restaurant resolves rather than waiting for the full menu.
    final restaurant =
        ref.watch(restaurantDetailProvider(widget.restaurantId)).value ??
        const Restaurant(
          id: '',
          name: '',
          cuisine: '',
          rating: 0,
          deliveryMinutes: 0,
          distanceKm: 0,
          deliveryFee: 0,
          discount: 0,
          imageUrl: '',
        );
    final allItems = [
      for (final section
          in ref.watch(restaurantMenuProvider(widget.restaurantId)).value ??
              const <MenuSection>[])
        ...section.items,
    ];
    final items = allItems
        .where(
          (item) =>
              (!_vegOnly || item.isVeg) &&
              item.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final cart = ref.watch(appControllerProvider.select((state) => state.cart));
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AppIconAction(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  translucent: true,
                  onPressed: () => context.pop(),
                ),
              ),
              leadingWidth: 56,
              actions: [
                AppIconAction(
                  onPressed: () {},
                  icon: Icons.favorite_border_rounded,
                  tooltip: 'Save restaurant',
                  translucent: true,
                ),
                const SizedBox(width: 6),
                AppIconAction(
                  onPressed: () {},
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share restaurant',
                  translucent: true,
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      url: restaurant.imageUrl,
                      fit: BoxFit.cover,
                      semanticLabel: restaurant.name,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x55000000)],
                          stops: [0.55, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        AppPill(
                          label: '${restaurant.rating}',
                          icon: Icons.star_rounded,
                          background: AppColors.successLight,
                          foreground: const Color(0xFF137333),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(restaurant.cuisine),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 18),
                        const SizedBox(width: 5),
                        Text('${restaurant.deliveryMinutes} min'),
                        const SizedBox(width: 16),
                        const Icon(Icons.near_me_outlined, size: 18),
                        const SizedBox(width: 5),
                        Text('${restaurant.distanceKm} km'),
                      ],
                    ),
                    if (restaurant.foodShare) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push('/shared/s1'),
                        child: PremiumSurface(
                          color: AppColors.primaryVeryLight,
                          borderColor: AppColors.primaryLight,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                color: AppColors.dark,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FoodShare available',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.dark,
                                      ),
                                    ),
                                    Text(
                                      '3 nearby users are ordering · Save ₹72–₹110',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.dark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppSearchBar(
                            hint: 'Search inside menu',
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ),
                        const SizedBox(width: 9),
                        FilterChip(
                          label: const Text('Veg'),
                          avatar: const Icon(Icons.eco_rounded, size: 17),
                          selected: _vegOnly,
                          onSelected: (value) =>
                              setState(() => _vegOnly = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeaderDelegate(),
            ),
          ],
          body: TabBarView(
            children: [
              for (final _ in List.generate(5, (index) => index))
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _MenuItemTile(
                      item: item,
                      quantity: cart[item.id] ?? 0,
                      onTap: () => context.push('/food-item/${item.id}'),
                      onAdd: () => ref
                          .read(appControllerProvider.notifier)
                          .addItem(item, restaurantId: widget.restaurantId),
                      onRemove: () => ref
                          .read(appControllerProvider.notifier)
                          .removeItem(item.id),
                    );
                  },
                ),
            ],
          ),
        ),
        bottomNavigationBar: ref.watch(cartCountProvider) > 0
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CartSummaryBar(
                    count: ref.watch(cartCountProvider),
                    store: restaurant.name,
                    total: ref.watch(cartTotalProvider),
                    onTap: () => context.push('/cart'),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabHeaderDelegate();

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return const ColoredBox(
      color: Colors.white,
      child: TabBar(
        isScrollable: true,
        tabs: [
          Tab(text: 'Recommended'),
          Tab(text: 'Bestsellers'),
          Tab(text: 'Main course'),
          Tab(text: 'Breads'),
          Tab(text: 'Beverages'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => false;
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.quantity,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  final CatalogItem item;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          item.isVeg ? Icons.eco_rounded : Icons.circle,
                          color: item.isVeg
                              ? AppColors.success
                              : AppColors.error,
                          size: 16,
                        ),
                        if (item.id == 'f1' || item.id == 'f2') ...[
                          const SizedBox(width: 7),
                          const AppPill(
                            label: 'Bestseller',
                            icon: Icons.local_fire_department_outlined,
                            background: AppColors.warningLight,
                            foreground: Color(0xFF8A6100),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${item.price}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '4.7',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Customisable',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 116,
                child: Column(
                  children: [
                    AppNetworkImage(
                      url: item.imageUrl,
                      width: 116,
                      height: 106,
                      borderRadius: 15,
                      semanticLabel: item.name,
                    ),
                    const SizedBox(height: 7),
                    QuantityControl(
                      quantity: quantity,
                      onAdd: onAdd,
                      onRemove: onRemove,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FoodItemDetailsScreen extends ConsumerStatefulWidget {
  const FoodItemDetailsScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<FoodItemDetailsScreen> createState() =>
      _FoodItemDetailsScreenState();
}

class _FoodItemDetailsScreenState extends ConsumerState<FoodItemDetailsScreen> {
  String _size = 'Regular';
  final Set<String> _addons = {};

  @override
  Widget build(BuildContext context) {
    final item = MockData.itemById(widget.itemId);
    final quantity = ref.watch(
      appControllerProvider.select((state) => state.cart[item.id] ?? 0),
    );
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 330,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: AppNetworkImage(
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
                      color: item.isVeg ? AppColors.success : AppColors.error,
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '₹${item.price}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 9),
                Text(
                  '${item.subtitle}. Prepared fresh with carefully selected ingredients and our signature house seasoning.',
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.light,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: AppColors.dark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FoodShare price preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              'Save another ₹${item.price * item.sharedDiscount ~/ 100} when the group reaches 5 people',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Choose size',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _size,
                  onChanged: (value) => setState(() => _size = value!),
                  child: Column(
                    children: [
                      for (final size in const [('Regular', 0), ('Large', 80)])
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(size.$1),
                          secondary: Text(
                            size.$2 == 0 ? 'Included' : '+₹${size.$2}',
                          ),
                          value: size.$1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text('Add-ons', style: Theme.of(context).textTheme.titleMedium),
                for (final addon in const [
                  ('Extra cheese', 49),
                  ('House dip', 29),
                  ('Fresh salad', 39),
                ])
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(addon.$1),
                    secondary: Text('+₹${addon.$2}'),
                    value: _addons.contains(addon.$1),
                    onChanged: (value) => setState(
                      () => value!
                          ? _addons.add(addon.$1)
                          : _addons.remove(addon.$1),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              QuantityControl(
                quantity: quantity,
                onAdd: () =>
                    ref.read(appControllerProvider.notifier).addItem(item),
                onRemove: () => ref
                    .read(appControllerProvider.notifier)
                    .removeItem(item.id),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: quantity == 0
                      ? 'Add to cart • ₹${item.price}'
                      : 'View cart • ₹${ref.watch(cartTotalProvider)}',
                  onPressed: quantity == 0
                      ? () => ref
                            .read(appControllerProvider.notifier)
                            .addItem(item)
                      : () => context.push('/cart'),
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final item = MockData.itemById(widget.itemId);
    final quantity = ref.watch(
      appControllerProvider.select((state) => state.cart[item.id] ?? 0),
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
                  color: index == _page ? AppColors.primary : AppColors.border,
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
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
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.dark),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delivery in 12 minutes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              QuantityControl(
                quantity: quantity,
                onAdd: () =>
                    ref.read(appControllerProvider.notifier).addItem(item),
                onRemove: () => ref
                    .read(appControllerProvider.notifier)
                    .removeItem(item.id),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: quantity == 0
                      ? 'Add to basket • ₹${item.price}'
                      : 'View basket • ₹${ref.watch(cartTotalProvider)}',
                  onPressed: quantity == 0
                      ? () => ref
                            .read(appControllerProvider.notifier)
                            .addItem(item)
                      : () => context.push('/cart'),
                ),
              ),
            ],
          ),
        ),
      ),
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
