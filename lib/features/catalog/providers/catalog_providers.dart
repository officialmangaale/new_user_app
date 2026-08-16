import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/catalog_repository.dart';
import '../../authentication/providers/auth_providers.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

/// Home feed. Location is optional — restaurant-service returns a non-located
/// listing when lat/lng are omitted, which is what the web client relies on
/// before the customer grants location access.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchHomeFeed();
});

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  return ref.watch(catalogRepositoryProvider).fetchRestaurants();
});

final restaurantDetailProvider = FutureProvider.family<Restaurant, String>((
  ref,
  restaurantId,
) {
  return ref.watch(catalogRepositoryProvider).fetchRestaurantDetail(
    restaurantId,
  );
});

final restaurantMenuProvider = FutureProvider.family<List<MenuSection>, String>((
  ref,
  restaurantId,
) {
  return ref.watch(catalogRepositoryProvider).fetchRestaurantMenu(restaurantId);
});
