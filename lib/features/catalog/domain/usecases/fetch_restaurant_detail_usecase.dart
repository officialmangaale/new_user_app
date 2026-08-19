import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchRestaurantDetailUseCase {
  const FetchRestaurantDetailUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<Restaurant>> call(String restaurantId) {
    return _repository.fetchRestaurantDetail(restaurantId);
  }
}
