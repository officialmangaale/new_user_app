import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/features/orders/data/repositories/orders_repository_impl.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OrdersRepositoryImpl _repo(_Adapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://restaurant.test',
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  )..httpClientAdapter = adapter;
  return OrdersRepositoryImpl(ApiClient(restaurantDio: dio, userDio: Dio()));
}

void main() {
  test('cancelOrder posts to the customer cancel endpoint', () async {
    final adapter = _Adapter(200, {
      'success': true,
      'data': {'order_id': 42, 'order_status': 'cancelled'},
    });

    final result = await _repo(adapter).cancelOrder('42');

    expect(result.isSuccess, isTrue);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/customer-web/orders/42/cancel');
  });

  test('a refusal comes back as a failure with the server reason', () async {
    const reason =
        'The restaurant has already accepted your order, so it can no longer be cancelled here.';
    final adapter = _Adapter(409, {'success': false, 'message': reason});

    final result = await _repo(adapter).cancelOrder('42');

    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull?.message, contains('already accepted'));
    expect(result.failureOrNull?.statusCode, 409);
  });
}
