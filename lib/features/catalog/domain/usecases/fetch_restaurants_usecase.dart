import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchRestaurantsUseCase {
  const FetchRestaurantsUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<List<Restaurant>>> call({
    double? lat,
    double? lng,
    double radiusKm = 7,
    int page = 1,
    int limit = 20,
  }) {
    return _repository.fetchRestaurants(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      page: page,
      limit: limit,
    );
  }
}
