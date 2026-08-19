import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchCategoriesUseCase {
  const FetchCategoriesUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<List<HomeCategory>>> call({
    double? lat,
    double? lng,
    double radiusKm = 7,
  }) {
    return _repository.fetchCategories(lat: lat, lng: lng, radiusKm: radiusKm);
  }
}
