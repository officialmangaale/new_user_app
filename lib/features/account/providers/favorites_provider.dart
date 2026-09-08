import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/providers/orders_providers.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/account_repository.dart';

final favoriteRestaurantsProvider = FutureProvider.autoDispose<List<FavoriteRestaurant>>((ref) async {
  return ref.read(accountRepositoryProvider).fetchFavoriteRestaurants();
});

final favoriteGroceryItemsProvider = FutureProvider.autoDispose<List<FavoriteGroceryItem>>((ref) async {
  return ref.read(accountRepositoryProvider).fetchFavoriteGroceryItems();
});

final toggleFavoriteRestaurantProvider = Provider.autoDispose((ref) {
  return (String restaurantId) async {
    final result = await ref.read(accountRepositoryProvider).toggleFavoriteRestaurant(restaurantId);
    ref.invalidate(favoriteRestaurantsProvider);
    return result;
  };
});

final toggleFavoriteGroceryProvider = Provider.autoDispose((ref) {
  return (String productId) async {
    final result = await ref.read(accountRepositoryProvider).toggleFavoriteGroceryItem(productId);
    ref.invalidate(favoriteGroceryItemsProvider);
    return result;
  };
});
