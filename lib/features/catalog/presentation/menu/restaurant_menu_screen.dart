import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_ui.dart' show ErrorState;
import '../../../../core/widgets/async_view.dart';
import '../../../cart/presentation/floating_cart.dart';
import '../../../cart/presentation/product_cart_animation.dart';
import '../../../cart/providers/cart_controller.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../providers/catalog_providers.dart';
import '../add_to_cart.dart';
import 'category_chips.dart';
import 'menu_controls.dart';
import 'menu_header.dart';
import 'menu_item_row.dart';
import 'menu_skeleton.dart';
import 'menu_styles.dart';
import 'veg_mark.dart';

/// Restaurant menu: cover + info card, search/veg filter, category chips that
/// track the scroll position, dish rows and a floating cart bar.
///
/// Shared by every restaurant; all content and imagery come from the
/// restaurant's data and all colours from [AppColors].
class RestaurantDetailsScreen extends ConsumerStatefulWidget {
  const RestaurantDetailsScreen({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  ConsumerState<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState
    extends ConsumerState<RestaurantDetailsScreen> {
  static const double _cartBarHeight = 60;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _chipsSlotKey = GlobalKey();
  final _searchRowKey = GlobalKey();
  final _sectionKeys = <String, GlobalKey>{};

  bool _vegOnly = false;
  String _query = '';

  // Scroll-derived chrome. Offsets are in scroll-content coordinates so the
  // sticky chips and top bar are computed from the live scroll offset and
  // never lag a frame behind the list.
  final _chrome = ValueNotifier<_Chrome>(const _Chrome());
  double _slotOffset = double.infinity;
  double _searchOffset = 0;
  List<double> _headerOffsets = const [];
  List<String> _visibleSectionIds = const [];
  double _topInset = 0;
  bool _programmatic = false;
  int _activeOverride = -1;

  // Extra space after the last dish so even the final category can be
  // scrolled up under the chips when the user picks it.
  double _filler = 0;
  double _trailingPad = 0;

  double get _barBottom => _topInset + kMenuCollapsedBarHeight;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrollEvent);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScrollEvent);
    _scroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _chrome.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String sectionId) =>
      _sectionKeys.putIfAbsent(sectionId, GlobalKey.new);

  double? _contentOffsetOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    return viewport?.getOffsetToReveal(box, 0).offset;
  }

  /// Re-reads where the sticky slot, search row and section headers sit.
  /// Lazily built rows refine list extents as they scroll into view, so this
  /// also runs on every scroll event (a handful of cheap lookups).
  void _onScrollEvent() {
    _refreshOffsets();
    _onScroll();
  }

  void _measure() {
    _refreshOffsets();
    _fitFiller();
    _onScroll();
  }

  void _refreshOffsets() {
    _slotOffset = _contentOffsetOf(_chipsSlotKey) ?? double.infinity;
    _searchOffset = _contentOffsetOf(_searchRowKey) ?? _searchOffset;
    _headerOffsets = [
      for (final id in _visibleSectionIds)
        _contentOffsetOf(_keyFor(id)) ?? double.infinity,
    ];
  }

  void _fitFiller() {
    if (!_scroll.hasClients || _headerOffsets.isEmpty) return;
    final last = _headerOffsets.last;
    if (!last.isFinite) return;
    final position = _scroll.position;
    final contentEnd =
        position.maxScrollExtent + position.viewportDimension - _filler;
    final lastExtent = contentEnd - last;
    final wanted = math.max(
      0.0,
      position.viewportDimension -
          _barBottom -
          kCategoryChipsHeight -
          lastExtent -
          _trailingPad,
    );
    if ((wanted - _filler).abs() > 1) {
      setState(() => _filler = wanted);
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    final bannerEnd = kMenuBannerHeight; // inset cancels with the bar's inset
    final barT = ((offset - (bannerEnd - kMenuCollapsedBarHeight - 30)) / 30)
        .clamp(0.0, 1.0);
    final stuck = offset >= _slotOffset - _barBottom;
    var active = _chrome.value.activeIndex;
    if (!_programmatic) {
      active = 0;
      final line = offset + _barBottom + kCategoryChipsHeight + 12;
      for (var i = 0; i < _headerOffsets.length; i++) {
        if (_headerOffsets[i] <= line) active = i;
      }
      if (_scroll.hasClients &&
          _headerOffsets.isNotEmpty &&
          offset >= _scroll.position.maxScrollExtent - 4) {
        active = _headerOffsets.length - 1;
      }
    } else if (_activeOverride >= 0) {
      active = _activeOverride;
    }
    final next = _Chrome(
      barOpacity: barT,
      chipsTop: math.max(_slotOffset - offset, _barBottom),
      stuck: stuck,
      activeIndex: active,
    );
    if (next != _chrome.value) _chrome.value = next;
  }

  Future<void> _selectSection(int index) async {
    if (index < 0 || index >= _headerOffsets.length || !_scroll.hasClients) {
      return;
    }
    _measure();
    final position = _scroll.position;
    double target() =>
        (_headerOffsets[index] - _barBottom - kCategoryChipsHeight).clamp(
          0.0,
          position.maxScrollExtent,
        );
    _programmatic = true;
    _activeOverride = index;
    _chrome.value = _chrome.value.copyWith(activeIndex: index);
    final reduce = MediaQuery.disableAnimationsOf(context);
    try {
      if (reduce) {
        _scroll.jumpTo(target());
      } else {
        await _scroll.animateTo(
          target(),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        );
      }
      // Lazily built rows above the target change estimated extents while
      // scrolling; settle on the measured position.
      if (!mounted) return;
      _measure();
      if ((position.pixels - target()).abs() > 1.5) _scroll.jumpTo(target());
    } finally {
      _programmatic = false;
      _activeOverride = -1;
      if (mounted) _onScroll();
    }
  }

  Future<void> _focusSearch() async {
    if (!_scroll.hasClients) return;
    _measure();
    final target = (_searchOffset - _barBottom - 8).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
    if (mounted) _searchFocus.requestFocus();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _vegOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _topInset = MediaQuery.paddingOf(context).top;
    final detail = ref.watch(restaurantDetailProvider(widget.restaurantId));
    final restaurant = detail.value;
    // Without a resolved restaurant there is no name or logo to show, so a
    // failure gets a retry and a pending request gets the skeleton.
    if (restaurant == null) {
      return Scaffold(
        backgroundColor: AppColors.pageTint,
        body: detail.hasError
            ? SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: MenuRoundButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Back',
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ErrorState(
                        offline: isOfflineError(detail.error!),
                        onRetry: () => ref.invalidate(
                          restaurantDetailProvider(widget.restaurantId),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const MenuSkeleton(),
      );
    }

    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final menuSections = menuAsync.value ?? const <MenuSection>[];
    final menuLoading = menuAsync.isLoading && !menuAsync.hasValue;
    final menuFailed = menuAsync.hasError && !menuAsync.hasValue;

    final search = _query.trim().toLowerCase();
    final visibleSections = [
      for (final section in menuSections)
        MenuSection(
          id: section.id,
          name: section.name.isEmpty ? 'Menu' : section.name,
          items: section.items
              .where(
                (item) =>
                    (!_vegOnly || item.isVeg) &&
                    (search.isEmpty ||
                        item.name.toLowerCase().contains(search) ||
                        item.subtitle.toLowerCase().contains(search)),
              )
              .toList(growable: false),
        ),
    ].where((section) => section.items.isNotEmpty).toList(growable: false);
    _visibleSectionIds = [
      for (var i = 0; i < visibleSections.length; i++)
        _sectionKeyId(visibleSections[i], i),
    ];
    final labels = [for (final s in visibleSections) s.name];
    final cartCount = ref.watch(cartCountProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final listBottom = cartCount > 0
        ? _cartBarHeight + 20 + bottomInset + 24
        : bottomInset + 32;
    _trailingPad = listBottom;
    final ordersEnabled = restaurant.isOpen != false;
    final hasMenu = menuSections.any((s) => s.items.isNotEmpty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    return Scaffold(
      backgroundColor: AppColors.pageTint,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: MenuHeader(
                  restaurant: restaurant,
                  topInset: _topInset,
                  onBack: () => context.pop(),
                  onFavourite: () {},
                  onShare: () {},
                  onFoodShare: () => context.push('/shared-list?mode=food'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  key: _searchRowKey,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: MenuSearchBar(
                          controller: _search,
                          focusNode: _searchFocus,
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      VegToggle(
                        value: _vegOnly,
                        onChanged: (value) => setState(() => _vegOnly = value),
                      ),
                    ],
                  ),
                ),
              ),
              // Placeholder the sticky chips are laid over.
              SliverToBoxAdapter(
                child: SizedBox(
                  key: _chipsSlotKey,
                  height: visibleSections.isEmpty ? 0 : kCategoryChipsHeight,
                ),
              ),
              if (menuLoading)
                const SliverToBoxAdapter(child: MenuRowsSkeleton())
              else if (menuFailed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ErrorState(
                      offline: isOfflineError(menuAsync.error!),
                      onRetry: () => ref.invalidate(
                        restaurantMenuProvider(widget.restaurantId),
                      ),
                    ),
                  ),
                )
              else if (visibleSections.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyMenu(
                    hasMenu: hasMenu,
                    query: _query.trim(),
                    vegOnly: _vegOnly,
                    onClear: _clearFilters,
                  ),
                )
              else
                for (var s = 0; s < visibleSections.length; s++) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      key: _keyFor(_visibleSectionIds[s]),
                      title: visibleSections[s].name,
                      count: visibleSections[s].items.length,
                    ),
                  ),
                  _SectionItems(
                    restaurantId: widget.restaurantId,
                    items: visibleSections[s].items,
                    ordersEnabled: ordersEnabled,
                  ),
                ],
              SliverToBoxAdapter(child: SizedBox(height: listBottom + _filler)),
            ],
          ),
          // Collapsed top bar + sticky chips, both driven by scroll offset.
          ValueListenableBuilder<_Chrome>(
            valueListenable: _chrome,
            builder: (context, chrome, _) {
              return Stack(
                children: [
                  if (labels.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: chrome.chipsTop,
                      child: CategoryChips(
                        labels: labels,
                        activeIndex: math.min(
                          chrome.activeIndex,
                          labels.length - 1,
                        ),
                        elevated: chrome.stuck,
                        onSelected: _selectSection,
                      ),
                    ),
                  // Not built at all while hidden, so it is also absent from
                  // the semantics tree.
                  if (chrome.barOpacity > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: IgnorePointer(
                        ignoring: chrome.barOpacity < 0.5,
                        child: Opacity(
                          opacity: chrome.barOpacity,
                          child: MenuCollapsedBar(
                            restaurant: restaurant,
                            topInset: _topInset,
                            onBack: () => context.pop(),
                            onSearch: _focusSearch,
                            onFavourite: () {},
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 + bottomInset,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: cartCount > 0
                  ? const FloatingCartBar(
                      key: ValueKey('menu-cart-bar'),
                      summary: true,
                    )
                  : const SizedBox.shrink(key: ValueKey('no-cart-bar')),
            ),
          ),
        ],
      ),
    );
  }

  /// Section ids can repeat or be empty across restaurants; the index makes
  /// the key unique within one render.
  static String _sectionKeyId(MenuSection section, int index) =>
      '${section.id.isEmpty ? section.name : section.id}#$index';
}

class _Chrome {
  const _Chrome({
    this.barOpacity = 0,
    this.chipsTop = double.maxFinite,
    this.stuck = false,
    this.activeIndex = 0,
  });

  final double barOpacity;
  final double chipsTop;
  final bool stuck;
  final int activeIndex;

  _Chrome copyWith({int? activeIndex}) => _Chrome(
    barOpacity: barOpacity,
    chipsTop: chipsTop,
    stuck: stuck,
    activeIndex: activeIndex ?? this.activeIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is _Chrome &&
      other.barOpacity == barOpacity &&
      other.chipsTop == chipsTop &&
      other.stuck == stuck &&
      other.activeIndex == activeIndex;

  @override
  int get hashCode => Object.hash(barOpacity, chipsTop, stuck, activeIndex);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, super.key});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MenuText.sectionTitle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count ${count == 1 ? 'item' : 'items'}', style: MenuText.meta),
        ],
      ),
    );
  }
}

class _SectionItems extends StatelessWidget {
  const _SectionItems({
    required this.restaurantId,
    required this.items,
    required this.ordersEnabled,
  });

  final String restaurantId;
  final List<CatalogItem> items;
  final bool ordersEnabled;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const ColoredBox(
        color: AppColors.surface,
        child: DashedDivider(indent: 16),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return ColoredBox(
          color: AppColors.surface,
          child: Consumer(
            builder: (context, ref, _) {
              final quantity = ref.watch(
                cartControllerProvider.select(
                  (state) => state.quantityForItem(
                    item.id,
                    type: item.type,
                    storeId: item.storeId,
                  ),
                ),
              );
              return MenuItemRow(
                item: item,
                quantity: quantity,
                ordersEnabled: ordersEnabled,
                onTap: () => context.push('/food-item/${item.id}'),
                onAdd: (imageKey, addKey) => addItemToCart(
                  context,
                  ref,
                  item,
                  restaurantId: restaurantId,
                  origin: ProductAddOrigin(
                    imageKey: imageKey,
                    addButtonKey: addKey,
                  ),
                ),
                onRemove: () => ref
                    .read(cartControllerProvider.notifier)
                    .removeItemById(item.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu({
    required this.hasMenu,
    required this.query,
    required this.vegOnly,
    required this.onClear,
  });

  final bool hasMenu;
  final String query;
  final bool vegOnly;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final filtered = hasMenu && (query.isNotEmpty || vegOnly);
    final title = !hasMenu
        ? 'Menu unavailable'
        : query.isNotEmpty
        ? "No dishes match '$query'"
        : 'No vegetarian dishes here';
    final message = !hasMenu
        ? 'This restaurant has no online menu items right now.'
        : 'Try a different search or clear the filters.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
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
              filtered ? Icons.search_off_rounded : Icons.restaurant_outlined,
              size: 32,
              color: AppColors.deepTeal,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: MenuText.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: MenuText.meta),
          if (filtered) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onClear,
              child: Text(query.isNotEmpty ? 'Clear search' : 'Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}
