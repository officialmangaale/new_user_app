import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/nature/widgets/leaf_accent.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../app_state/providers/app_controller.dart';
import '../../catalog/presentation/add_to_cart.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../cart/providers/cart_controller.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../orders/providers/orders_providers.dart';
import '../../shared_orders/presentation/shared_order_screens.dart';

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
      extendBody: true,
      body: IndexedStack(index: state.activeHomeTab, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
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
              onModeToggle: ref.read(appControllerProvider.notifier).toggleMode,
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
    final addresses = state.authenticated
        ? ref.watch(addressesProvider).value ?? const <CustomerAddress>[]
        : const <CustomerAddress>[];
    final selectedAddress = _preferredAddress(addresses);
    // The merchant list is the feed's primary payload; its state decides
    // whether the page can render at all. Previously every state collapsed to
    // an empty list, so a failed request looked identical to "nothing nearby"
    // and a slow one showed a blank page with no spinner.
    final merchantsAsync = grocery
        ? ref.watch(groceryMerchantsProvider)
        : ref.watch(restaurantsProvider);
    final merchants = merchantsAsync.value ?? const <Restaurant>[];
    final items = grocery
        ? ref.watch(nearbyGroceryProductsProvider).value ??
              const <CatalogItem>[]
        : ref.watch(homeFeedProvider).value?.featuredItems ??
              const <CatalogItem>[];
    // Server-curated banners from `/api/home`. The previous source — merchants
    // with `discount > 0` — was always empty because the discovery endpoints
    // do not return a discount field, so the carousel never rendered.
    final banners = grocery
        ? const <HomeBanner>[]
        : ref.watch(homeFeedProvider).value?.banners ?? const <HomeBanner>[];

    // Only take over the page when there is genuinely nothing to show; once
    // any merchant has arrived the feed keeps rendering through refreshes.
    if (merchants.isEmpty && merchantsAsync.isLoading) {
      return const SafeArea(bottom: false, child: LoadingSkeleton());
    }
    if (merchants.isEmpty && merchantsAsync.hasError) {
      return SafeArea(
        bottom: false,
        child: ErrorState(
          offline: isOfflineError(merchantsAsync.error!),
          onRetry: () => ref.invalidate(
            grocery ? groceryMerchantsProvider : restaurantsProvider,
          ),
        ),
      );
    }

    return ColoredBox(
      // Home's own ground, applied here rather than to the global theme so the
      // pilot is contained: every other screen keeps AppColors.background until
      // this treatment is reviewed.
      color: NatureColors.offWhite,
      child: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: CustomScrollView(
            key: ValueKey(state.mode),
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHero(
                  mode: state.mode,
                  locationLabel: _deliveryLocationLabel(selectedAddress),
                  cartCount: ref.watch(cartCountProvider),
                  onLocationTap: () => _showLocationSheet(context, ref),
                  onCartTap: () => context.push('/cart'),
                  onProfileTap: () => context.push('/profile'),
                  onSearchTap: () => context.push('/search'),
                ),
              ),
              SliverToBoxAdapter(child: _CategoryStrip(grocery: grocery)),
              if (banners.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.md),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _OfferCarousel(banners: banners),
                  ),
                ),
              ],
              if (merchants.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _HomeSectionHeader(
                      title: grocery ? 'Stores near you' : 'Popular near you',
                      onViewAll: () => context.push('/search'),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                SliverToBoxAdapter(
                  child: _RestaurantStrip(
                    restaurants: merchants,
                    grocery: grocery,
                  ),
                ),
              ],
              if (items.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _HomeSectionHeader(
                      title: grocery ? 'Popular groceries' : 'Popular dishes',
                      onViewAll: () => context.push('/search'),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.sm),
                ),
                _productStrip(ref, items, grocery),
              ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      AppSpacing.navigationClearance +
                      (cartVisible ? 72 : 0) +
                      AppSpacing.md,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  void _showLocationSheet(BuildContext context, WidgetRef ref) {
    final authenticated = ref.read(appControllerProvider).authenticated;
    final addresses = authenticated
        ? ref.read(addressesProvider).value ?? const <CustomerAddress>[]
        : const <CustomerAddress>[];
    final selectedAddress = _preferredAddress(addresses);
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
              PremiumSurface(
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: selectedAddress == null
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current location',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text('Save an address to make checkout faster'),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _addressTitle(selectedAddress),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(selectedAddress.singleLine),
                              ],
                            ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
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

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.mode,
    required this.locationLabel,
    required this.cartCount,
    required this.onLocationTap,
    required this.onCartTap,
    required this.onProfileTap,
    required this.onSearchTap,
  });

  final DeliveryMode mode;
  final String locationLabel;
  final int cartCount;
  final VoidCallback onLocationTap;
  final VoidCallback onCartTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final grocery = mode == DeliveryMode.grocery;
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroWidth = constraints.maxWidth;
        final imageWidth = (heroWidth * 0.62).clamp(196.0, 275.0);
        return SizedBox(
          height: 340,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: 27,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF5FCFA), Color(0xFFDDF5F1)],
                    ),
                  ),
                  child: CustomPaint(painter: const _HeroWavePainter()),
                ),
              ),
              Positioned(
                right: -imageWidth * 0.17,
                top: 58,
                width: imageWidth,
                height: 205,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Image.asset(
                    grocery
                        ? 'assets/images/home-hero-grocery.png'
                        : 'assets/images/home-hero-food.png',
                    key: ValueKey(mode),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 112,
                bottom: 28,
                width: heroWidth * 0.61,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFEFFAF7), Color(0x00EFFAF7)],
                      stops: [0.68, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: 8,
                child: _HeroHeader(
                  locationLabel: locationLabel,
                  cartCount: cartCount,
                  onLocationTap: onLocationTap,
                  onCartTap: onCartTap,
                  onProfileTap: onProfileTap,
                ),
              ),
              Positioned(
                left: AppSpacing.screenPadding,
                bottom: 92,
                width: math.max(176, heroWidth * 0.58),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grocery ? 'Freshness, delivered' : 'Good evening',
                      maxLines: 2,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: heroWidth < 360 ? 27 : 30,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      grocery
                          ? 'What does your kitchen need today?'
                          : 'What are you craving today?',
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: heroWidth < 360 ? 14 : 15,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                bottom: 0,
                child: _HeroSearchBar(
                  hint: grocery
                      ? 'Search groceries, fruits, vegetables...'
                      : 'Search dishes or restaurants...',
                  onTap: onSearchTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.locationLabel,
    required this.cartCount,
    required this.onLocationTap,
    required this.onCartTap,
    required this.onProfileTap,
  });

  final String locationLabel;
  final int cartCount;
  final VoidCallback onLocationTap;
  final VoidCallback onCartTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivering to',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // A plain cart icon again. The collection point is now the clay pot in
        // the summary bar at the bottom of the screen, and water has to fall
        // *down* into it — so this icon deliberately stops being a target and
        // loses the turquoise disc and arrival ripple it wore in Phase 2. Its
        // position, route and badge are exactly as they were.
        _HeaderCircleAction(
          tooltip: 'Cart',
          icon: Icons.shopping_cart_outlined,
          badgeCount: cartCount,
          onPressed: onCartTap,
        ),
        const SizedBox(width: 8),
        _HeaderCircleAction(
          tooltip: 'Profile',
          icon: Icons.person_outline_rounded,
          onPressed: onProfileTap,
        ),
      ],
    );
  }
}

class _HeaderCircleAction extends StatelessWidget {
  const _HeaderCircleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            maximumSize: const Size.square(44),
            backgroundColor: Colors.white.withValues(alpha: 0.96),
            foregroundColor: AppColors.textPrimary,
            shadowColor: const Color(0x22075E54),
            elevation: 3,
          ),
          icon: Icon(icon, size: 23),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -3,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroSearchBar extends StatelessWidget {
  const _HeroSearchBar({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      textField: true,
      label: hint,
      child: Material(
        color: Colors.white,
        elevation: 7,
        shadowColor: const Color(0x1A075E54),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                const SizedBox(width: 17),
                const Icon(Icons.search_rounded, size: 25),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                IconButton(
                  tooltip: 'Search filters',
                  onPressed: onTap,
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroWavePainter extends CustomPainter {
  const _HeroWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.69)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.82,
        size.width * 0.58,
        size.height * 0.47,
        size.width,
        size.height * 0.61,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _HeroWavePainter oldDelegate) => false;
}

class _CategoryStrip extends ConsumerStatefulWidget {
  const _CategoryStrip({required this.grocery});

  final bool grocery;

  @override
  ConsumerState<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends ConsumerState<_CategoryStrip> {
  String _selectedKey = '__all__';

  @override
  void didUpdateWidget(covariant _CategoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grocery != widget.grocery) _selectedKey = '__all__';
  }

  @override
  Widget build(BuildContext context) {
    final backendCategories =
        (widget.grocery
                ? ref.watch(groceryCategoriesProvider)
                : ref.watch(categoriesProvider))
            .value ??
        const <HomeCategory>[];
    final categories = <HomeCategory>[
      const HomeCategory(
        key: '__all__',
        name: 'All',
        imageUrl: '',
        icon: 'all',
        itemCount: 0,
      ),
      ...backendCategories.where(
        (category) =>
            category.key.toLowerCase() != 'all' &&
            category.name.toLowerCase() != 'all',
      ),
    ];

    return SizedBox(
      height: 114,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          0,
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
              if (category.key == '__all__') return;
              context.push(
                '/category/${Uri.encodeComponent(category.key)}'
                '?title=${Uri.encodeQueryComponent(category.name)}',
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferCarousel extends StatefulWidget {
  const _OfferCarousel({required this.banners});

  final List<HomeBanner> banners;

  @override
  State<_OfferCarousel> createState() => _OfferCarouselState();
}

class _OfferCarouselState extends State<_OfferCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return _OfferBanner(
                banner: banner,
                onTap: () => context.push(
                  banner.restaurantId.isEmpty
                      ? '/search'
                      : '/restaurant/${banner.restaurantId}',
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (index) {
              final active = index == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 19 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.textMuted,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({required this.banner, required this.onTap});

  final HomeBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFEAF8F5), Color(0xFFD8F3EE)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner.imageUrl.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 170,
                child: AppNetworkImage(
                  url: banner.imageUrl,
                  semanticLabel: banner.title,
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF0FAF8),
                    Color(0xFFF0FAF8),
                    Color(0x00F0FAF8),
                  ],
                  stops: [0, 0.54, 0.84],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
              child: FractionallySizedBox(
                widthFactor: 0.65,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        banner.subtitle.isEmpty
                            ? 'FEATURED'
                            : banner.subtitle.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      banner.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 35,
                      child: FilledButton.icon(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 35),
                          padding: const EdgeInsets.only(left: 13, right: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        label: Text(
                          banner.ctaText.isEmpty ? 'Order now' : banner.ctaText,
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // A small leaf beside the heading. Decoration only: it sits before the
        // text rather than over it, is excluded from semantics, and ignores
        // pointers, so the heading reads and behaves exactly as it did.
        const Padding(
          padding: EdgeInsets.only(right: 7, bottom: 2),
          child: LeafAccent(size: 15),
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 3),
          ),
          label: const Text('View all'),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
        ),
      ],
    );
  }
}

CustomerAddress? _preferredAddress(List<CustomerAddress> addresses) {
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.isEmpty ? null : addresses.first;
}

String _deliveryLocationLabel(CustomerAddress? address) {
  if (address == null) return 'Current location';
  final label = address.label.trim();
  final area = address.area.trim();
  if (label.isNotEmpty && area.isNotEmpty) return '$label · $area';
  if (label.isNotEmpty) return label;
  if (address.singleLine.isNotEmpty) return address.singleLine;
  return 'Saved address';
}

String _addressTitle(CustomerAddress address) {
  final label = address.label.trim();
  return label.isEmpty ? 'Delivery address' : 'Deliver to $label';
}

class _RestaurantStrip extends StatelessWidget {
  const _RestaurantStrip({required this.restaurants, required this.grocery});

  final List<Restaurant> restaurants;
  final bool grocery;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = ((constraints.maxWidth - 48) / 2.15).clamp(
          150.0,
          174.0,
        );
        return SizedBox(
          height: 225,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: restaurants.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => RestaurantCard(
              restaurant: restaurants[index],
              width: cardWidth,
              compact: true,
              onTap: grocery
                  ? () => context.push('/search')
                  : () => context.push('/restaurant/${restaurants[index].id}'),
            ),
          ),
        );
      },
    );
  }
}
