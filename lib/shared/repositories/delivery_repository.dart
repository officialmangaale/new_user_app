import '../../core/services/api_client.dart';
import '../mock_data/mock_data.dart';
import '../models/app_models.dart';

abstract interface class DeliveryRepository {
  Future<List<Restaurant>> getRestaurants();
  Future<List<CatalogItem>> getCatalog();
  Future<List<SharedGroup>> getSharedGroups();
  Future<List<DeliveryOrder>> getOrders();
  Future<List<WalletTransaction>> getWalletTransactions();
  Future<List<AppNotificationItem>> getNotifications();
}

class MockDeliveryRepository implements DeliveryRepository {
  const MockDeliveryRepository();

  @override
  Future<List<CatalogItem>> getCatalog() async => MockData.catalog;

  @override
  Future<List<AppNotificationItem>> getNotifications() async =>
      MockData.notifications;

  @override
  Future<List<DeliveryOrder>> getOrders() async => MockData.orders;

  @override
  Future<List<Restaurant>> getRestaurants() async => MockData.restaurants;

  @override
  Future<List<SharedGroup>> getSharedGroups() async => MockData.groups;

  @override
  Future<List<WalletTransaction>> getWalletTransactions() async =>
      MockData.walletTransactions;
}

/// API implementation boundary. Swap this into Riverpod when the backend is
/// available; UI models and screens remain unchanged.
class DioDeliveryRepository {
  const DioDeliveryRepository(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> getJson(String endpoint) async {
    final response = await client.dio.get<Map<String, dynamic>>(endpoint);
    return response.data ?? const <String, dynamic>{};
  }
}
