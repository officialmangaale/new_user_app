import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../account/presentation/profile_screen.dart';
import '../../app_state/providers/app_controller.dart';
import '../../account/providers/engagement_providers.dart';
import '../../catalog/presentation/add_to_cart.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../cart/providers/cart_controller.dart';
import '../../shared_orders/presentation/shared_order_screens.dart';

class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final cartLines = ref.watch(cartLinesProvider);
    final screens = [
      SharedOrderListingScreen(mode: state.mode, embedded: true),
      const DeliveryHomeFeed(),
      const ProfileScreen(embedded: true),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: state.activeHomeTab, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.bottomCenter,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: cartCount > 0
                  ? Padding(
                      key: const ValueKey('cart'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CartSummaryBar(
                        count: cartCount,
                        store: cartLines.first.item.store,
                        total: cartTotal,
                        onTap: () => context.push('/cart'),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty-cart')),
            ),
            FloatingHomeNavigation(
              mode: state.mode,
              index: state.activeHomeTab,
              hasActiveGroup: state.joinedGroupIds.isNotEmpty,
              onChanged: ref.read(appControllerProvider.notifier).setHomeTab,
            ),
          ],
        ),
      ),
    );
  }
}

class DeliveryHomeFeed extends ConsumerWidget {
  const DeliveryHomeFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final grocery = state.mode == DeliveryMode.grocery;
    final cartVisible = ref.watch(cartCountProvider) > 0;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: PageStorageKey(state.mode),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              0,
            ),
            sliver: SliverList.list(
              children: [
                AppLocationHeader(
                  mode: state.mode,
                  onLocationTap: () => _showLocationSheet(context),
                  onNotifications: () => context.push('/notifications'),
                ),
                const SizedBox(height: AppSpacing.ml),
                Text(
                  grocery
                      ? 'Fresh picks, right on time'
                      : 'Good evening, Aarav',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  grocery
                      ? 'Delivery in 20–30 minutes'
                      : 'What would you like delivered today?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppSearchBar(
                  hint: grocery
                      ? 'Search milk, fruits, snacks…'
                      : 'Search dishes or restaurants…',
                  // Opens the dedicated search screen rather than editing in
                  // place, so results have room and the query can be shared.
                  onTap: () => context.push('/search'),
                ),
                const SizedBox(height: AppSpacing.md),
                DeliveryModeSwitch(
                  mode: state.mode,
                  onChanged: ref.read(appControllerProvider.notifier).setMode,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
          SliverToBoxAdapter(child: _CategoryStrip(grocery: grocery)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            sliver: SliverList.list(
              children: [
                PremiumFeatureBanner(
                  title: grocery
                      ? 'Freshness meets shared savings'
                      : 'Great food, better together',
                  subtitle: grocery
                      ? 'Unlock up to 12% off with Share Basket'
                      : 'Join FoodShare and save up to ₹120',
                  imageUrl: grocery
                      ? 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800'
                      : 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
                  actionLabel: grocery
                      ? 'Explore baskets'
                      : 'Explore FoodShare',
                  onAction: () =>
                      ref.read(appControllerProvider.notifier).setHomeTab(0),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: grocery
                      ? 'Share Basket near you'
                      : 'FoodShare near you',
                  subtitle: 'Team up nearby and unlock better savings',
                  onViewAll: () =>
                      ref.read(appControllerProvider.notifier).setHomeTab(0),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          SliverToBoxAdapter(child: _HomeGroupStrip(mode: state.mode)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          if (!grocery)
            ..._foodSections(context, ref)
          else
            ..._grocerySections(context, ref),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.navigationClearance + (cartVisible ? 72 : 0),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _foodSections(BuildContext context, WidgetRef ref) {
    // Strips render empty while the request is in flight rather than pushing a
    // skeleton into every carousel; the pull-to-refresh above covers retry.
    final restaurants =
        ref.watch(restaurantsProvider).value ?? const <Restaurant>[];
    return [
      _sliverHeader(
        context,
        'Popular near you',
        'Loved around your neighbourhood',
      ),
      SliverToBoxAdapter(child: _RestaurantStrip(restaurants: restaurants)),
      _gap(),
      _sliverHeader(context, 'Recommended for you', 'Picked for your evening'),
      _productStrip(ref, CatalogItemType.food),
      _gap(),
      _sliverHeader(context, 'Reorder your favourites', 'One tap away'),
      _productStrip(ref, CatalogItemType.food, reversed: true),
      _gap(),
      _sliverHeader(context, 'Under 30 minutes', 'Fast local favourites'),
      SliverToBoxAdapter(
        child: _RestaurantStrip(
          restaurants: restaurants.reversed.toList(growable: false),
        ),
      ),
      _gap(),
      _sliverHeader(context, 'Best rated', 'Consistently delightful'),
      _productStrip(ref, CatalogItemType.food),
      _gap(),
      _sliverHeader(
        context,
        'Offers up to 40% off',
        'Big flavour, lighter bill',
      ),
      SliverToBoxAdapter(child: _RestaurantStrip(restaurants: restaurants)),
    ];
  }

  List<Widget> _grocerySections(BuildContext context, WidgetRef ref) {
    const titles = [
      ('Daily essentials', 'Everything you need today'),
      ('Buy again', 'Your regulars, ready to add'),
      ('Fresh fruits and vegetables', 'Quality checked this morning'),
      ('Breakfast and dairy', 'Start the day well'),
      ('Snacks under ₹99', 'Small prices, useful picks'),
      ('Household essentials', 'For a well-stocked home'),
      ('Personal care', 'Everyday care, delivered'),
      ('Best Share Basket deals', 'Save more with neighbours'),
      ('Recommended for you', 'Selected for your household'),
    ];
    return [
      for (var i = 0; i < titles.length; i++) ...[
        _sliverHeader(context, titles[i].$1, titles[i].$2),
        _productStrip(ref, CatalogItemType.grocery, reversed: i.isOdd),
        if (i != titles.length - 1) _gap(),
      ],
    ];
  }

  SliverPadding _sliverHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      sliver: SliverToBoxAdapter(
        child: SectionHeader(
          title: title,
          subtitle: subtitle,
          onViewAll: () {},
        ),
      ),
    );
  }

  SliverToBoxAdapter _productStrip(
    WidgetRef ref,
    CatalogItemType type, {
    bool reversed = false,
  }) {
    var items =
        (ref.watch(homeFeedProvider).value?.featuredItems ??
                const <CatalogItem>[])
            .where((item) => item.type == type)
            .toList();
    if (reversed) items = items.reversed.toList();
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 278,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            return ProductCard(
              item: item,
              quantity: ref.watch(cartControllerProvider.select((state) => state.quantityForItem(item.id))),
              onAdd: () => addItemToCart(context, ref, item),
              onRemove: () =>
                  ref.read(cartControllerProvider.notifier).removeItemById(item.id),
              onTap: () => context.push(
                type == CatalogItemType.food
                    ? '/food-item/${item.id}'
                    : '/product/${item.id}',
              ),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _gap() =>
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg));

  void _showLocationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const PremiumSurface(
                child: Row(
                  children: [
                    Icon(Icons.home_rounded, color: AppColors.primaryDark),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Home',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text('12, 4th Main Road, Indiranagar'),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle_rounded, color: AppColors.primary),
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

class _CategoryStrip extends ConsumerStatefulWidget {
  const _CategoryStrip({required this.grocery});

  final bool grocery;

  @override
  ConsumerState<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends ConsumerState<_CategoryStrip> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <HomeCategory>[];
    if (categories.isEmpty) return const SizedBox(height: 112);

    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (_, index) {
          final category = categories[index];
          return PremiumCategoryTile(
            label: category.name,
            imageUrl: category.imageUrl,
            iconKey: category.icon,
            selected: category.key == _selectedKey,
            onTap: () {
              setState(() => _selectedKey = category.key);
              context.push('/category/${Uri.encodeComponent(category.key)}');
            },
          );
        },
      ),
    );
  }
}

class _HomeGroupStrip extends ConsumerWidget {
  const _HomeGroupStrip({required this.mode});

  final DeliveryMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups =
        ref.watch(sharedGroupsProvider(mode)).value ?? const <SharedGroup>[];
    final state = ref.watch(appControllerProvider);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 386 + ((textScale - 1).clamp(0, 1) * 96),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) {
          final group = groups[index];
          return SharedOrderCard(
            group: group,
            compact: true,
            joined: state.joinedGroupIds.contains(group.id),
            onTap: () => context.push('/shared/${group.id}'),
            onJoin: () => handleJoinGroup(context, ref, group),
          );
        },
      ),
    );
  }
}

class _RestaurantStrip extends StatelessWidget {
  const _RestaurantStrip({required this.restaurants});

  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 254,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: restaurants.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) => RestaurantCard(
          restaurant: restaurants[index],
          onTap: () => context.push('/restaurant/${restaurants[index].id}'),
        ),
      ),
    );
  }
}
