import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchCategoryItemsUseCase {
  const FetchCategoryItemsUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<List<CatalogItem>>> call(
    String categoryKey, {
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) {
    return _repository.fetchCategoryItems(
      categoryKey,
      lat: lat,
      lng: lng,
      page: page,
      limit: limit,
    );
  }
}
