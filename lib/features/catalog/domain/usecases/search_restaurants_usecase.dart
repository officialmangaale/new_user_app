import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class SearchRestaurantsUseCase {
  const SearchRestaurantsUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<List<Restaurant>>> call(String query) {
    return _repository.searchRestaurants(query);
  }
}
