import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/features/orders/data/repositories/orders_repository_impl.dart';

/// Serves one canned JSON body, so the real repository parsing is exercised.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OrdersRepositoryImpl repositoryServing(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _StubAdapter(body);
  return OrdersRepositoryImpl(ApiClient(restaurantDio: dio, userDio: dio));
}

void main() {
  test('an assigned rider yields coordinates and a Maps link', () async {
    final repository = repositoryServing({
      'status': 'success',
      'data': {
        'order_id': 4242,
        'order_status': 'out_for_delivery',
        'status_message': 'On the way',
        'rider': {
          'name': 'Amrit',
          'phone': '9876543210',
          'latitude': 12.9716,
          'longitude': 77.5946,
          'maps_url':
              'https://www.google.com/maps/search/?api=1&query=12.971600,77.594600',
        },
      },
    });

    final result = await repository.trackOrder('4242');
    final tracking = result.dataOrNull;

    expect(tracking, isNotNull);
    expect(tracking!.riderName, 'Amrit');
    expect(tracking.riderLatitude, closeTo(12.9716, 1e-6));
    expect(tracking.riderLongitude, closeTo(77.5946, 1e-6));
    expect(tracking.hasRiderLocation, isTrue);
    expect(tracking.riderMapsUrl, contains('12.971600,77.594600'));
    expect(Uri.tryParse(tracking.riderMapsUrl)?.host, 'www.google.com');
  });

  test('no rider assigned yet leaves the location absent, not zeroed',
      () async {
    final repository = repositoryServing({
      'status': 'success',
      'data': {
        'order_id': 4242,
        'order_status': 'pending',
        'status_message': 'Waiting for the restaurant',
        'rider': null,
      },
    });

    final tracking = (await repository.trackOrder('4242')).dataOrNull;

    expect(tracking, isNotNull);
    expect(tracking!.riderLatitude, isNull,
        reason: 'a missing rider must not be reported at 0,0');
    expect(tracking.hasRiderLocation, isFalse);
    expect(tracking.riderMapsUrl, isEmpty);
  });

  test('an explicit 0,0 position is not treated as a real location', () async {
    final repository = repositoryServing({
      'status': 'success',
      'data': {
        'order_id': 4242,
        'order_status': 'picked_up',
        'rider': {'name': 'Amrit', 'latitude': 0, 'longitude': 0},
      },
    });

    final tracking = (await repository.trackOrder('4242')).dataOrNull;

    expect(tracking!.hasRiderLocation, isFalse);
  });
}
