import '../../../../core/error/result.dart';
import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository_interface.dart';

class FetchItemDetailUseCase {
  const FetchItemDetailUseCase(this._repository);

  final CatalogRepositoryInterface _repository;

  Future<Result<CatalogItem>> execute(String itemId) {
    return _repository.fetchItemDetail(itemId);
  }
}
