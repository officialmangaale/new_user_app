import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/widgets/delivery_cards.dart';
import '../providers/catalog_providers.dart';

/// Global search across restaurants, backed by `/customer-web/search`.
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search dishes or restaurants…',
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
          ? const EmptyState(
              icon: Icons.search_rounded,
              title: 'Find something to eat',
              message: 'Type at least two letters to search restaurants.',
            )
          : AsyncListView(
              value: ref.watch(searchResultsProvider(_query)),
              onRetry: () => ref.invalidate(searchResultsProvider(_query)),
              empty: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matches for “$_query”',
                message: 'Try a different dish, cuisine or restaurant name.',
              ),
              builder: (restaurants) => ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: restaurants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final restaurant = restaurants[index];
                  return RestaurantCard(
                    restaurant: restaurant,
                    onTap: () => context.push('/restaurant/${restaurant.id}'),
                  );
                },
              ),
            ),
    );
  }
}
