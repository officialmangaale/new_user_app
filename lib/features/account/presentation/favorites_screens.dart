import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../providers/favorites_provider.dart';

class FavoriteRestaurantsScreen extends ConsumerWidget {
  const FavoriteRestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(favoriteRestaurantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favourite Restaurants')),
      body: restaurantsAsync.when(
        data: (restaurants) {
          if (restaurants.isEmpty) {
            return const Center(child: Text('No favorite restaurants yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final r = restaurants[index];
              return ListTile(
                leading: r.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(r.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                      )
                    : Container(width: 50, height: 50, color: AppColors.light),
                title: Text(r.name, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(r.tags, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: AppColors.primary),
                  onPressed: () => ref.read(toggleFavoriteRestaurantProvider)(r.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading favorites: $e')),
      ),
    );
  }
}

class FavoriteGroceryScreen extends ConsumerWidget {
  const FavoriteGroceryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(favoriteGroceryItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Grocery Items')),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No saved grocery items yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final i = items[index];
              return ListTile(
                leading: i.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(i.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                      )
                    : Container(width: 50, height: 50, color: AppColors.light),
                title: Text(i.name, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('₹${i.sellingPrice} • ${i.packageSize}'),
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark, color: AppColors.primary),
                  onPressed: () => ref.read(toggleFavoriteGroceryProvider)(i.productId),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading favorites: $e')),
      ),
    );
  }
}
