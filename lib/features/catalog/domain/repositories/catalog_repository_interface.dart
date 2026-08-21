import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';

/// Defines the contract for catalog operations.
/// 
/// The catalog repository handles fetching menus, restaurants, and home feed data.
/// It strictly returns [Result] types to prevent exceptions from bubbling up.
abstract interface class CatalogRepositoryInterface {
  /// Fetches the home feed containing restaurants and featured items.
  Future<Result<HomeFeed>> fetchHomeFeed({double? lat, double? lng});

  /// Fetches a paginated list of nearby restaurants.
  Future<Result<List<Restaurant>>> fetchRestaurants({
    double? lat,
    double? lng,
    double radiusKm = 7,
    int page = 1,
    int limit = 20,
  });

  /// Fetches nearby grocery merchants for the customer's delivery location.
  Future<Result<List<Restaurant>>> fetchGroceryMerchants({
    required double lat,
    required double lng,
    double radiusKm = 7,
    int limit = 20,
  });

  /// Fetches detailed information for a specific restaurant.
  Future<Result<Restaurant>> fetchRestaurantDetail(String restaurantId);

  /// Fetches the menu sections and items for a specific restaurant.
  Future<Result<List<MenuSection>>> fetchRestaurantMenu(
    String restaurantId, {
    String? storeName,
  });

  /// Fetches the list of food categories (the home rail).
  Future<Result<List<HomeCategory>>> fetchCategories({
    double? lat,
    double? lng,
    double radiusKm = 7,
  });

  /// Fetches grocery categories for one merchant.
  Future<Result<List<HomeCategory>>> fetchGroceryCategories(String merchantId);

  /// Fetches items that belong to a specific category.
  Future<Result<List<CatalogItem>>> fetchCategoryItems(
    String categoryKey, {
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  });

  /// Fetches grocery products for one merchant, optionally scoped to a category.
  Future<Result<List<CatalogItem>>> fetchGroceryProducts(
    String merchantId, {
    required double lat,
    required double lng,
    String? merchantName,
    String? categoryId,
    String? search,
  });

  /// Searches restaurants by query.
  Future<Result<List<Restaurant>>> searchRestaurants(String query);

  /// Fetches detailed information for a specific catalog item.
  Future<Result<CatalogItem>> fetchItemDetail(String itemId);
}
