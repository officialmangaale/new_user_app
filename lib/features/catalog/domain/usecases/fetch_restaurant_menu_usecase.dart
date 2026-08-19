import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchRestaurantMenuUseCase {
  const FetchRestaurantMenuUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<List<MenuSection>>> call(String restaurantId, {String? storeName}) {
    return _repository.fetchRestaurantMenu(restaurantId, storeName: storeName);
  }
}
