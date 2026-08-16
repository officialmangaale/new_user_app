import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/app_models.dart';
import '../../../shared/repositories/catalog_repository.dart';
import '../../app_state/providers/location_providers.dart';
import '../../authentication/providers/auth_providers.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

/// Home feed, scoped to the device location when one is available.
///
/// Location is optional — restaurant-service returns a non-located listing when
/// lat/lng are omitted, which is what the web client relies on before the
/// customer grants access. Both providers re-run once a fix arrives, so
/// "Popular near you" becomes genuinely near.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  return ref
      .watch(catalogRepositoryProvider)
      .fetchHomeFeed(lat: location?.latitude, lng: location?.longitude);
});

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  return ref
      .watch(catalogRepositoryProvider)
      .fetchRestaurants(lat: location?.latitude, lng: location?.longitude);
});

/// Home category rail, scoped to the device location when available.
final categoriesProvider = FutureProvider<List<HomeCategory>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  return ref
      .watch(catalogRepositoryProvider)
      .fetchCategories(lat: location?.latitude, lng: location?.longitude);
});

/// Dishes inside one category.
final categoryItemsProvider = FutureProvider.family<List<CatalogItem>, String>((
  ref,
  categoryKey,
) async {
  final location = await ref.watch(currentLocationProvider.future);
  return ref
      .watch(catalogRepositoryProvider)
      .fetchCategoryItems(
        categoryKey,
        lat: location?.latitude,
        lng: location?.longitude,
      );
});

/// Cross-restaurant search. Empty query returns nothing rather than the whole
/// catalogue, matching the web client.
final searchResultsProvider = FutureProvider.family<List<Restaurant>, String>((
  ref,
  query,
) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const <Restaurant>[];
  return ref.watch(catalogRepositoryProvider).searchRestaurants(trimmed);
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
