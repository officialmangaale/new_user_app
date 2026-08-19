import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/catalog/domain/repositories/catalog_repository_interface.dart';
import 'package:turquoise_delivery/features/catalog/domain/usecases/fetch_home_feed_usecase.dart';
import 'package:turquoise_delivery/features/catalog/domain/usecases/fetch_restaurants_usecase.dart';

class FakeCatalogRepository implements CatalogRepositoryInterface {
  bool shouldFail = false;

  @override
  Future<Result<HomeFeed>> fetchHomeFeed({double? lat, double? lng}) async {
    if (shouldFail) {
      return const Result.failure(UnknownFailure('Fake failure'));
    }
    return const Result.success(HomeFeed(restaurants: [], featuredItems: []));
  }

  @override
  Future<Result<List<HomeCategory>>> fetchCategories(
      {double? lat, double? lng, double radiusKm = 7}) async {
    return const Result.success([]);
  }

  @override
  Future<Result<List<CatalogItem>>> fetchCategoryItems(String categoryKey,
      {double? lat, double? lng, int page = 1, int limit = 20}) async {
    return const Result.success([]);
  }

  @override
  Future<Result<Restaurant>> fetchRestaurantDetail(String restaurantId) async {
    if (shouldFail) {
      return const Result.failure(UnknownFailure('Fake failure'));
    }
    return const Result.success(
      Restaurant(
          id: '1',
          name: 'Fake Restaurant',
          cuisine: 'Fake',
          rating: 4.5,
          deliveryMinutes: 30,
          distanceKm: 2,
          deliveryFee: 10,
          discount: 0,
          imageUrl: ''),
    );
  }

  @override
  Future<Result<List<MenuSection>>> fetchRestaurantMenu(String restaurantId,
      {String? storeName}) async {
    return const Result.success([]);
  }

  @override
  Future<Result<List<Restaurant>>> fetchRestaurants(
      {double? lat,
      double? lng,
      double radiusKm = 7,
      int page = 1,
      int limit = 20}) async {
    if (shouldFail) {
      return const Result.failure(UnknownFailure('Fake failure'));
    }
    return const Result.success([]);
  }

  @override
  Future<Result<List<Restaurant>>> searchRestaurants(String query) async {
    return const Result.success([]);
  }
}

void main() {
  group('Catalog Use Cases Tests', () {
    late FakeCatalogRepository repository;

    setUp(() {
      repository = FakeCatalogRepository();
    });

    test('FetchHomeFeedUseCase returns success', () async {
      final useCase = FetchHomeFeedUseCase(repository);
      final result = await useCase();

      expect(result.isSuccess, true);
      expect(result.dataOrNull, isA<HomeFeed>());
    });

    test('FetchHomeFeedUseCase returns failure', () async {
      repository.shouldFail = true;
      final useCase = FetchHomeFeedUseCase(repository);
      final result = await useCase();

      expect(result.isFailure, true);
      expect(result.failureOrNull?.message, 'Fake failure');
    });

    test('FetchRestaurantsUseCase returns success', () async {
      final useCase = FetchRestaurantsUseCase(repository);
      final result = await useCase();

      expect(result.isSuccess, true);
      expect(result.dataOrNull, isA<List<Restaurant>>());
    });
  });
}
