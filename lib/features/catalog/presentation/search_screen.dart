import 'dart:async';

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
import 'add_to_cart.dart';
import '../providers/catalog_providers.dart';

/// Global search across dishes and restaurants, backed by `/customer-web/search`.
///
/// Input is debounced so typing does not fire a request per keystroke.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final grocery =
        ref.watch(appControllerProvider).mode == DeliveryMode.grocery;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: grocery
                ? 'Search milk, fruits, snacks…'
                : 'Search dishes or restaurants…',
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
      body: _query.length < 2
          ? EmptyState(
              icon: Icons.search_rounded,
              title: grocery ? 'Find daily essentials' : 'Find something to eat',
              message: grocery
                  ? 'Type at least two letters to search nearby grocery products.'
                  : 'Type at least two letters to search restaurants.',
            )
          : grocery
              ? _GrocerySearchResults(query: _query)
              : AsyncView<CatalogSearchResults>(
                  value: ref.watch(catalogSearchResultsProvider(_query)),
                  onRetry: () =>
                      ref.invalidate(catalogSearchResultsProvider(_query)),
                  isEmpty: (results) => results.isEmpty,
                  empty: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches for “$_query”',
                    message:
                        'Try a different dish, cuisine or restaurant name.',
                  ),
                  builder: (results) => ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      if (results.items.isNotEmpty) ...[
                        const _SearchSectionTitle(title: 'Menu items'),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 278,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                          ),
                          itemCount: results.items.length,
                          itemBuilder: (context, index) {
                            final item = results.items[index];
                            return ProductCard(
                              width: double.infinity,
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
                              onAdd: () => _addSearchItem(context, ref, item),
                              onRemove: () => ref
                                  .read(cartControllerProvider.notifier)
                                  .removeItemById(item.id),
                              onTap: () => context.push('/food-item/${item.id}'),
                            );
                          },
                        ),
                      ],
                      if (results.restaurants.isNotEmpty) ...[
                        if (results.items.isNotEmpty)
                          const SizedBox(height: AppSpacing.lg),
                        const _SearchSectionTitle(title: 'Restaurants'),
                        const SizedBox(height: 10),
                        for (final restaurant in results.restaurants) ...[
                          SizedBox(
                            height: 254,
                            child: RestaurantCard(
                              restaurant: restaurant,
                              onTap: () =>
                                  context.push('/restaurant/${restaurant.id}'),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }
}

Future<void> _addSearchItem(
  BuildContext context,
  WidgetRef ref,
  CatalogItem item,
) async {
  try {
    final detailed = await ref.read(itemDetailProvider(item.id).future);
    if (!context.mounted) return;
    await addItemToCart(context, ref, detailed);
  } catch (_) {
    if (context.mounted) context.push('/food-item/${item.id}');
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _GrocerySearchResults extends ConsumerWidget {
  const _GrocerySearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncListView(
      value: ref.watch(grocerySearchResultsProvider(query)),
      onRetry: () => ref.invalidate(grocerySearchResultsProvider(query)),
      empty: EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for “$query”',
        message: 'Try a different product, brand or grocery keyword.',
      ),
      builder: (products) => GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 278,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final item = products[index];
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
            onRemove: () => ref
                .read(cartControllerProvider.notifier)
                .removeItemById(item.id),
            onTap: () => context.push('/product/${item.id}'),
          );
        },
      ),
    );
  }
}
