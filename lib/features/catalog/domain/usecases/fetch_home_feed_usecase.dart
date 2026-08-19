import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchHomeFeedUseCase {
  const FetchHomeFeedUseCase(this._repository);
  final CatalogRepositoryInterface _repository;

  Future<Result<HomeFeed>> call({double? lat, double? lng}) {
    return _repository.fetchHomeFeed(lat: lat, lng: lng);
  }
}
