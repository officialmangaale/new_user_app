import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../account/providers/favorites_provider.dart';
import '../../app_state/providers/app_controller.dart';
import '../../cart/providers/delivery_location.dart';
import '../../cart/presentation/product_cart_animation.dart';
import '../../cart/providers/cart_controller.dart';
import '../../catalog/presentation/add_to_cart.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../location/presentation/delivery_location_sheet.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../orders/providers/orders_providers.dart';
import '../../shared_orders/presentation/shared_order_screens.dart';
import 'widgets/home_header.dart';
import 'widgets/home_offer_carousel.dart';
import 'widgets/home_sections.dart';
import 'widgets/home_skeleton.dart';

class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final cartLines = ref.watch(cartLinesProvider);
    final screens = <Widget>[
      SharedOrderListingScreen(mode: state.mode, embedded: true),
      const DeliveryHomeFeed(),
      const OrdersScreen(embedded: true),
    ];

    return Scaffold(
      backgroundColor: AppColors.pageTint,
      extendBody: false,
      body: IndexedStack(index: state.activeHomeTab, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: Duration.zero,
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
              onChanged: (tab) {
                ref.read(productCartAnimationProvider).clear();
                ref.read(appControllerProvider.notifier).setHomeTab(tab);
              },
              onModeToggle: () {
                ref.read(productCartAnimationProvider).clear();
                ref.read(appControllerProvider.notifier).toggleMode();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class DeliveryHomeFeed extends ConsumerStatefulWidget {
  const DeliveryHomeFeed({super.key});

  @override
  ConsumerState<DeliveryHomeFeed> createState() => _DeliveryHomeFeedState();
}

class _DeliveryHomeFeedState extends ConsumerState<DeliveryHomeFeed> {
  String _selectedCategory = '__all__';
  final Set<String> _filters = <String>{};
  DeliveryMode? _lastMode;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final grocery = state.mode == DeliveryMode.grocery;
    if (_lastMode != state.mode) {
      // A category or filter from one service means nothing in the other.
      _lastMode = state.mode;
      _selectedCategory = '__all__';
      _filters.clear();
    }
    final cartCount = ref.watch(cartCountProvider);
    // The merchant list is the feed's primary payload; its state decides
    // whether the sections can render.
    final merchantsAsync = grocery
        ? ref.watch(groceryMerchantsProvider)
        : ref.watch(restaurantsProvider);
    final merchants = merchantsAsync.value ?? const <Restaurant>[];
    final items = grocery
        ? ref.watch(nearbyGroceryProductsProvider).value ??
              const <CatalogItem>[]
        : ref.watch(homeFeedProvider).value?.featuredItems ??
              const <CatalogItem>[];
    // Server-curated banners from `/api/home`.
    final banners = grocery
        ? const <HomeBanner>[]
        : ref.watch(homeFeedProvider).value?.banners ?? const <HomeBanner>[];
    final profileName = state.authenticated
        ? ref.watch(profileProvider).value?.name
        : null;
    final favouriteIds = state.authenticated
        ? {
            for (final f
                in ref.watch(favoriteRestaurantsProvider).value ??
                    const <FavoriteRestaurant>[])
              f.id,
          }
        : null;
    // One canonical delivery location feeds the header, the list distances and
    // the cart; the header only describes it.
    final locationView = ref.watch(deliveryLocationViewProvider);
    final location = (locationView.primary, locationView.secondary);

    final loading = merchants.isEmpty && merchantsAsync.isLoading;
    final failed = merchants.isEmpty && merchantsAsync.hasError;

    final visible = merchants
        .where(
          (r) => kHomeFilters
              .where((f) => _filters.contains(f.id))
              .every((f) => f.test(r)),
        )
        .toList(growable: false);
    final popular = _popular(visible);
    final filterOptions = grocery
        ? const <HomeFilterOption>[]
        : kHomeFilters
              .where(
                (f) =>
                    _filters.contains(f.id) || merchants.any((r) => f.test(r)),
              )
              .toList(growable: false);
    final knownOpenState = visible.any((r) => r.isOpen != null);
    final openCount = visible.where((r) => r.isOpen != false).length;

    final categories = _categories(grocery);

    return ColoredBox(
      color: AppColors.pageTint,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeaderBand(
              mode: state.mode,
              primaryLocation: location.$1,
              secondaryLocation: location.$2,
              greeting: greetingFor(DateTime.now(), profileName),
              cartCount: cartCount,
              accountInitial: _initialOf(profileName),
              searchHint: grocery
                  ? 'Search groceries, fruits, vegetables...'
                  : 'Search "momos" or "pizza"',
              onLocationTap: () => showDeliveryLocationSheet(context),
              onCartTap: () => context.push('/cart'),
              onAccountTap: () => context.push('/profile'),
              onSearchTap: () => context.push('/search'),
            ),
          ),
          if (filterOptions.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: HomeFilterChips(
                  options: filterOptions,
                  selected: _filters,
                  onToggle: (id) => setState(() {
                    if (!_filters.remove(id)) _filters.add(id);
                  }),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: HomeSectionTitle(
                title: grocery ? 'What do you need?' : "What's on your mind?",
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: HomeCategoryRail(
                categories: categories,
                selectedKey: _selectedCategory,
                onTap: (category) {
                  setState(() => _selectedCategory = category.key);
                  if (category.key == '__all__') return;
                  context.push(
                    '/category/${Uri.encodeComponent(category.key)}'
                    '?title=${Uri.encodeQueryComponent(category.name)}',
                  );
                },
              ),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(child: HomeFeedSkeleton())
          else if (failed)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 360,
                child: ErrorState(
                  offline: isOfflineError(merchantsAsync.error!),
                  onRetry: () => ref.invalidate(
                    grocery ? groceryMerchantsProvider : restaurantsProvider,
                  ),
                ),
              ),
            )
          else ...[
            ..._offerSection(banners, merchants),
            if (popular.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: HomeSectionTitle(
                    title: grocery ? 'Stores near you' : 'Popular near you',
                    onViewAll: () => context.push('/search'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    itemCount: popular.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => PopularRestaurantCard(
                      restaurant: popular[index],
                      onTap: () =>
                          _openMerchant(context, popular[index], grocery),
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: HomeSectionTitle(
                  title: grocery ? 'All stores' : 'All restaurants',
                  trailingText: visible.isEmpty
                      ? null
                      : knownOpenState
                      ? '$openCount open now'
                      : '${visible.length} nearby',
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyFeed(
                  filtered: merchants.isNotEmpty,
                  grocery: grocery,
                  onClearFilters: () => setState(_filters.clear),
                  onChangeLocation: () => showDeliveryLocationSheet(context),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final restaurant = visible[index];
                    return HomeRestaurantCard(
                      restaurant: restaurant,
                      favourite: grocery || favouriteIds == null
                          ? null
                          : favouriteIds.contains(restaurant.id),
                      onFavourite: () => ref.read(
                        toggleFavoriteRestaurantProvider,
                      )(restaurant.id),
                      onTap: () => _openMerchant(context, restaurant, grocery),
                    );
                  },
                ),
              ),
            if (items.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: HomeSectionTitle(
                    title: grocery ? 'Popular groceries' : 'Popular dishes',
                    onViewAll: () => context.push('/search'),
                  ),
                ),
              ),
              _productStrip(ref, items, grocery),
            ],
          ],
          // The nav bar is the Scaffold's bottom bar, so the list already
          // ends above it; this is breathing room under the last card.
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  List<Widget> _offerSection(
    List<HomeBanner> banners,
    List<Restaurant> merchants,
  ) {
    final resolved = resolveOfferBanners(banners, merchants);
    if (resolved.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: HomeOfferCarousel(
            banners: resolved,
            onOpen: (banner) => context.push(
              banner.restaurantId.isEmpty
                  ? '/search'
                  : '/restaurant/${banner.restaurantId}',
            ),
          ),
        ),
      ),
    ];
  }

  List<HomeCategory> _categories(bool grocery) {
    final backend =
        (grocery
                ? ref.watch(groceryCategoriesProvider)
                : ref.watch(categoriesProvider))
            .value ??
        const <HomeCategory>[];
    return [
      const HomeCategory(
        key: '__all__',
        name: 'All',
        imageUrl: '',
        icon: 'all',
        itemCount: 0,
      ),
      ...backend.where(
        (category) =>
            category.key.toLowerCase() != 'all' &&
            category.name.toLowerCase() != 'all',
      ),
    ];
  }

  void _openMerchant(BuildContext context, Restaurant r, bool grocery) {
    context.push(grocery ? '/search' : '/restaurant/${r.id}');
  }

  /// Best-rated first; unrated restaurants follow in feed order.
  List<Restaurant> _popular(List<Restaurant> source) {
    final sorted = [...source];
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(10).toList(growable: false);
  }

  String _initialOf(String? name) {
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  SliverToBoxAdapter _productStrip(
    WidgetRef ref,
    List<CatalogItem> source,
    bool grocery,
  ) {
    final expectedType = grocery
        ? CatalogItemType.grocery
        : CatalogItemType.food;
    final items = source
        .where((item) => item.type == expectedType)
        .toList(growable: false);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 278,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
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
              onAdd: (origin) =>
                  addItemToCart(context, ref, item, origin: origin),
              onRemove: () => ref
                  .read(cartControllerProvider.notifier)
                  .removeItemById(item.id),
              onTap: () => context.push(
                grocery ? '/product/${item.id}' : '/food-item/${item.id}',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({
    required this.filtered,
    required this.grocery,
    required this.onClearFilters,
    required this.onChangeLocation,
  });

  /// True when restaurants exist but the active filters hide all of them.
  final bool filtered;
  final bool grocery;
  final VoidCallback onClearFilters;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final noun = grocery ? 'stores' : 'restaurants';
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filtered
                  ? Icons.filter_alt_off_outlined
                  : Icons.storefront_outlined,
              size: 32,
              color: AppColors.deepTeal,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'No $noun match these filters'
                : 'No $noun deliver here yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Try removing a filter.'
                : 'Try a different delivery location.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: filtered ? onClearFilters : onChangeLocation,
            child: Text(filtered ? 'Clear filters' : 'Change location'),
          ),
        ],
      ),
    );
  }
}
