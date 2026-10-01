import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/core/storage/campaign_attribution_storage.dart';
import 'package:turquoise_delivery/features/cart/domain/entities/cart_entities.dart';
import 'package:turquoise_delivery/features/orders/data/repositories/orders_repository_impl.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'order_id': 4242, 'order_status': 'pending'},
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OrdersRepositoryImpl _repository(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://restaurant.test'))
    ..httpClientAdapter = adapter;
  return OrdersRepositoryImpl(ApiClient(restaurantDio: dio, userDio: Dio()));
}

Future<void> _place(OrdersRepositoryImpl repository, String key) =>
    repository.placeOrder(
      restaurantId: '7',
      lines: const <CartLine>[],
      idempotencyKey: key,
      customerName: 'Test',
      customerPhone: '9876543210',
      deliveryAddressLine1: '1 Main Road',
      deliveryLatitude: 28.4,
      deliveryLongitude: 77.0,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an opened campaign is sent with the next order, once', () async {
    await const CampaignAttributionStorage().store(9);
    final adapter = _Adapter();
    final repository = _repository(adapter);

    await _place(repository, 'k1');
    expect(
      (adapter.requests.single.data as Map)['platform_campaign_id'],
      9,
      reason: 'the order the push led to is attributed to the campaign',
    );

    await _place(repository, 'k2');
    expect(
      (adapter.requests.last.data as Map).containsKey('platform_campaign_id'),
      isFalse,
      reason: 'a campaign is credited with one order, not every later one',
    );
  });

  test('no campaign means no attribution field', () async {
    final adapter = _Adapter();
    await _place(_repository(adapter), 'k1');
    expect(
      (adapter.requests.single.data as Map).containsKey('platform_campaign_id'),
      isFalse,
    );
  });

  test('a campaign opened more than 24 hours ago is ignored', () async {
    const storage = CampaignAttributionStorage();
    await storage.store(9, now: DateTime.now().subtract(const Duration(hours: 25)));
    expect(await storage.read(), isNull);
  });

  test('last touch wins', () async {
    const storage = CampaignAttributionStorage();
    await storage.store(3);
    await storage.store(4);
    expect(await storage.read(), 4);
  });
}
