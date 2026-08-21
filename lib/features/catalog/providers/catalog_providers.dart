import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../app_state/providers/location_providers.dart';
import '../../authentication/providers/auth_providers.dart';
import '../data/repositories/catalog_repository_impl.dart';
import '../domain/entities/catalog_entities.dart';
import '../domain/repositories/catalog_repository_interface.dart';
import '../domain/usecases/fetch_categories_usecase.dart';
import '../domain/usecases/fetch_category_items_usecase.dart';
import '../domain/usecases/fetch_home_feed_usecase.dart';
import '../domain/usecases/fetch_item_detail_usecase.dart';
import '../domain/usecases/fetch_restaurant_detail_usecase.dart';
import '../domain/usecases/fetch_restaurant_menu_usecase.dart';
import '../domain/usecases/fetch_restaurants_usecase.dart';
import '../domain/usecases/search_restaurants_usecase.dart';

final catalogRepositoryProvider = Provider<CatalogRepositoryInterface>((ref) {
  return CatalogRepositoryImpl(ref.watch(apiClientProvider));
});

final fetchHomeFeedUseCaseProvider = Provider((ref) => FetchHomeFeedUseCase(ref.watch(catalogRepositoryProvider)));
final fetchRestaurantsUseCaseProvider = Provider((ref) => FetchRestaurantsUseCase(ref.watch(catalogRepositoryProvider)));
final fetchCategoriesUseCaseProvider = Provider((ref) => FetchCategoriesUseCase(ref.watch(catalogRepositoryProvider)));
final fetchCategoryItemsUseCaseProvider = Provider((ref) => FetchCategoryItemsUseCase(ref.watch(catalogRepositoryProvider)));
final searchRestaurantsUseCaseProvider = Provider((ref) => SearchRestaurantsUseCase(ref.watch(catalogRepositoryProvider)));
final fetchRestaurantDetailUseCaseProvider = Provider((ref) => FetchRestaurantDetailUseCase(ref.watch(catalogRepositoryProvider)));
final fetchRestaurantMenuUseCaseProvider = Provider((ref) => FetchRestaurantMenuUseCase(ref.watch(catalogRepositoryProvider)));
final fetchItemDetailUseCaseProvider = Provider((ref) => FetchItemDetailUseCase(ref.watch(catalogRepositoryProvider)));

/// Helper to unwrap Results for UI providers
T _unwrap<T>(Result<T> result) {
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
}

/// Home feed, scoped to the device location when one is available.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  final result = await ref
      .watch(fetchHomeFeedUseCaseProvider)
      .call(lat: location?.latitude, lng: location?.longitude);
  return _unwrap(result);
});

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  final result = await ref
      .watch(fetchRestaurantsUseCaseProvider)
      .call(lat: location?.latitude, lng: location?.longitude);
  return _unwrap(result);
});

final groceryMerchantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  if (location == null) return const <Restaurant>[];
  final result = await ref
      .watch(catalogRepositoryProvider)
      .fetchGroceryMerchants(
        lat: location.latitude,
        lng: location.longitude,
      );
  return _unwrap(result);
});

final nearestGroceryMerchantProvider = FutureProvider<Restaurant?>((ref) async {
  final merchants = await ref.watch(groceryMerchantsProvider.future);
  return merchants.isEmpty ? null : merchants.first;
});

/// Home category rail, scoped to the device location when available.
final categoriesProvider = FutureProvider<List<HomeCategory>>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  final result = await ref
      .watch(fetchCategoriesUseCaseProvider)
      .call(lat: location?.latitude, lng: location?.longitude);
  return _unwrap(result);
});

final groceryCategoriesProvider = FutureProvider<List<HomeCategory>>((ref) async {
  final merchant = await ref.watch(nearestGroceryMerchantProvider.future);
  if (merchant == null) return const <HomeCategory>[];
  final result = await ref
      .watch(catalogRepositoryProvider)
      .fetchGroceryCategories(merchant.id);
  return _unwrap(result);
});

/// Dishes inside one category.
final categoryItemsProvider = FutureProvider.family<List<CatalogItem>, String>((
  ref,
  categoryKey,
) async {
  final location = await ref.watch(currentLocationProvider.future);
  final result = await ref
      .watch(fetchCategoryItemsUseCaseProvider)
      .call(
        categoryKey,
        lat: location?.latitude,
        lng: location?.longitude,
      );
  return _unwrap(result);
});

final nearbyGroceryProductsProvider = FutureProvider<List<CatalogItem>>((
  ref,
) async {
  final location = await ref.watch(currentLocationProvider.future);
  if (location == null) return const <CatalogItem>[];
  final merchant = await ref.watch(nearestGroceryMerchantProvider.future);
  if (merchant == null) return const <CatalogItem>[];
  final result = await ref
      .watch(catalogRepositoryProvider)
      .fetchGroceryProducts(
        merchant.id,
        lat: location.latitude,
        lng: location.longitude,
        merchantName: merchant.name,
      );
  return _unwrap(result);
});

final groceryCategoryItemsProvider =
    FutureProvider.family<List<CatalogItem>, String>((ref, categoryId) async {
  final location = await ref.watch(currentLocationProvider.future);
  if (location == null) return const <CatalogItem>[];
  final merchant = await ref.watch(nearestGroceryMerchantProvider.future);
  if (merchant == null) return const <CatalogItem>[];
  final result = await ref
      .watch(catalogRepositoryProvider)
      .fetchGroceryProducts(
        merchant.id,
        lat: location.latitude,
        lng: location.longitude,
        merchantName: merchant.name,
        categoryId: categoryId,
      );
  return _unwrap(result);
});

final grocerySearchResultsProvider =
    FutureProvider.family<List<CatalogItem>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const <CatalogItem>[];
  final location = await ref.watch(currentLocationProvider.future);
  if (location == null) return const <CatalogItem>[];
  final merchant = await ref.watch(nearestGroceryMerchantProvider.future);
  if (merchant == null) return const <CatalogItem>[];
  final result = await ref
      .watch(catalogRepositoryProvider)
      .fetchGroceryProducts(
        merchant.id,
        lat: location.latitude,
        lng: location.longitude,
        merchantName: merchant.name,
        search: trimmed,
      );
  return _unwrap(result);
});

final groceryProductDetailProvider =
    FutureProvider.family<CatalogItem, String>((ref, productId) async {
  final products = await ref.watch(nearbyGroceryProductsProvider.future);
  for (final product in products) {
    if (product.id == productId) return product;
  }
  throw Exception('This grocery product is not available near you right now.');
});

/// Cross-restaurant search. Empty query returns nothing rather than the whole
/// catalogue, matching the web client.
final searchResultsProvider = FutureProvider.family<List<Restaurant>, String>((
  ref,
  query,
) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const <Restaurant>[];
  final result = await ref.watch(searchRestaurantsUseCaseProvider).call(trimmed);
  return _unwrap(result);
});

final restaurantDetailProvider = FutureProvider.family<Restaurant, String>((
  ref,
  restaurantId,
) async {
  final result = await ref.watch(fetchRestaurantDetailUseCaseProvider).call(restaurantId);
  return _unwrap(result);
});

final restaurantMenuProvider = FutureProvider.family<List<MenuSection>, String>((
  ref,
  restaurantId,
) async {
  final result = await ref.watch(fetchRestaurantMenuUseCaseProvider).call(restaurantId);
  return _unwrap(result);
});

final itemDetailProvider = FutureProvider.family<CatalogItem, String>((
  ref,
  itemId,
) async {
  final result = await ref.watch(fetchItemDetailUseCaseProvider).execute(itemId);
  return _unwrap(result);
});
