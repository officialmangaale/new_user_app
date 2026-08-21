import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/premium_components.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../../account/presentation/profile_screen.dart';
import '../../app_state/providers/app_controller.dart';
import '../../account/providers/engagement_providers.dart';
import '../../catalog/presentation/add_to_cart.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../cart/providers/cart_controller.dart';
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
    final addresses = state.authenticated
        ? ref.watch(addressesProvider).value ?? const <CustomerAddress>[]
        : const <CustomerAddress>[];
    final selectedAddress = _preferredAddress(addresses);
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
                  locationLabel: _deliveryLocationLabel(selectedAddress),
                  onLocationTap: () => _showLocationSheet(context, ref),
                  onNotifications: () => context.push('/notifications'),
                ),
                const SizedBox(height: AppSpacing.ml),
                Text(
                  grocery
                      ? 'Fresh picks, right on time'
                      : 'Food delivery near you',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  grocery
                      ? 'Fresh groceries from nearby stores'
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
        'Restaurants near you',
        'Open restaurants for your delivery location',
      ),
      SliverToBoxAdapter(child: _RestaurantStrip(restaurants: restaurants)),
      _gap(),
      _sliverHeader(context, 'Popular near you', 'From the live menu catalog'),
      _productStrip(ref, CatalogItemType.food),
    ];
  }

  List<Widget> _grocerySections(BuildContext context, WidgetRef ref) {
    final merchants =
        ref.watch(groceryMerchantsProvider).value ?? const <Restaurant>[];
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
      _sliverHeader(
        context,
        'Grocery stores near you',
        'Closest open shops for your delivery location',
      ),
      SliverToBoxAdapter(
        child: _RestaurantStrip(restaurants: merchants, grocery: true),
      ),
      _gap(),
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
    final source = type == CatalogItemType.grocery
        ? ref.watch(nearbyGroceryProductsProvider).value ??
            const <CatalogItem>[]
        : ref.watch(homeFeedProvider).value?.featuredItems ??
            const <CatalogItem>[];
    var items = source.where((item) => item.type == type).toList();
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
                                Text(
                                  'Save an address to make checkout faster',
                                ),
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

CustomerAddress? _preferredAddress(List<CustomerAddress> addresses) {
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.isEmpty ? null : addresses.first;
}

String _deliveryLocationLabel(CustomerAddress? address) {
  if (address == null) return 'Use current location';
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
    final categories = (widget.grocery
            ? ref.watch(groceryCategoriesProvider)
            : ref.watch(categoriesProvider))
        .value ?? const <HomeCategory>[];
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
  const _RestaurantStrip({required this.restaurants, this.grocery = false});

  final List<Restaurant> restaurants;
  final bool grocery;

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
          onTap: grocery
              ? null
              : () => context.push('/restaurant/${restaurants[index].id}'),
        ),
      ),
    );
  }
}
