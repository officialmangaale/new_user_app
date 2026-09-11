import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/features/account/address/pincode_lookup.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

/// Answers every request with [status]/[body] and records what was sent.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Object body;
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

Dio _dio(String baseUrl, _FakeAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('addresses use user-service', () {
    // The root cause: the app called restaurant-service /customer-web/addresses,
    // stubs that answer 501 for every save and [] for every list.
    test(
      'saving posts to /customers/me/addresses and reads the saved address',
      () async {
        final user = _FakeAdapter(201, {
          'status': 'success',
          'data': {
            'address': {
              'address_id': 'a1',
              'label': 'Home',
              'address_line1': '108, Sector 49',
              'area': 'Sector 49',
              'city': 'Gurgaon',
              'state': 'Haryana',
              'district': 'Gurgaon',
              'pincode': '122003',
              'latitude': 28.4089,
              'longitude': 77.0532,
              'location_accuracy_meters': 25.0,
              'is_default': true,
            },
          },
        });
        final restaurant = _FakeAdapter(501, {'message': 'not configured'});
        final repository = AccountRepository(
          ApiClient(
            restaurantDio: _dio('https://restaurant.test', restaurant),
            userDio: _dio('https://user.test', user),
          ),
        );

        final saved = await repository.addAddress(
          const CustomerAddress(
            id: '',
            label: 'Home',
            addressLine1: '108, Sector 49',
            area: 'Sector 49',
            city: 'Gurgaon',
            state: 'Haryana',
            district: 'Gurgaon',
            pincode: '122003',
            isDefault: true,
            latitude: 28.4089,
            longitude: 77.0532,
            locationAccuracyMeters: 25,
          ),
        );

        expect(
          restaurant.requests,
          isEmpty,
          reason: 'the stub must not be called',
        );
        final request = user.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/customers/me/addresses');
        final sent = request.data as Map<String, dynamic>;
        expect(sent['latitude'], 28.4089);
        expect(sent['longitude'], 77.0532);
        expect(sent['location_accuracy_meters'], 25);
        expect(sent['state'], 'Haryana');
        expect(saved.id, 'a1');
        expect(saved.hasPin, isTrue);
        expect(saved.district, 'Gurgaon');
      },
    );

    test('an address without a pin sends no coordinates at all', () {
      final json = const CustomerAddress(
        id: '',
        label: 'Home',
        addressLine1: '12 MG Road',
        area: 'Indiranagar',
        city: 'Bengaluru',
        pincode: '560038',
        isDefault: false,
      ).toJson();
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      expect(json.containsKey('location_accuracy_meters'), isFalse);
    });

    test('the list reads user-service addresses', () async {
      final user = _FakeAdapter(200, {
        'data': {
          'addresses': [
            {
              'address_id': 'a1',
              'label': 'Home',
              'address_line1': 'x',
              'is_default': true,
            },
          ],
        },
      });
      final repository = AccountRepository(
        ApiClient(
          restaurantDio: _dio('https://restaurant.test', _FakeAdapter(200, {})),
          userDio: _dio('https://user.test', user),
        ),
      );

      final list = await repository.fetchAddresses();

      expect(user.requests.single.path, '/customers/me/addresses');
      expect(list.single.id, 'a1');
      expect(list.single.isDefault, isTrue);
    });

    test('a server validation error keeps its field for the form', () async {
      final user = _FakeAdapter(400, {
        'status': 'error',
        'message': 'valid pincode is required',
        'error': {
          'code': 'validation_error',
          'details': {'pincode': 'valid pincode is required'},
        },
      });
      final repository = AccountRepository(
        ApiClient(
          restaurantDio: _dio('https://restaurant.test', _FakeAdapter(200, {})),
          userDio: _dio('https://user.test', user),
        ),
      );

      await expectLater(
        repository.addAddress(
          const CustomerAddress(
            id: '',
            label: 'Home',
            addressLine1: 'x',
            area: 'y',
            city: '',
            pincode: '12200',
            isDefault: false,
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having(
                (e) => e.errors?['pincode'],
                'field',
                'valid pincode is required',
              ),
        ),
      );
    });
  });

  group('pincode lookup', () {
    final success = [
      {
        'Status': 'Success',
        'PostOffice': [
          {
            'Name': 'Jharsa',
            'District': 'Gurgaon',
            'State': 'Haryana',
            'DeliveryStatus': 'Delivery',
          },
        ],
      },
    ];

    // The third party must never see the customer's login token.
    test('sends no Authorization header', () async {
      final adapter = _FakeAdapter(200, success);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.postalpincode.in'))
        ..httpClientAdapter = adapter;

      await PostalPincodeLookup(dio: dio).lookup('122003');

      expect(adapter.requests.single.path, '/pincode/122003');
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('caches a result for the session', () async {
      final adapter = _FakeAdapter(200, success);
      final lookup = PostalPincodeLookup(
        dio: Dio()..httpClientAdapter = adapter,
      );

      await lookup.lookup('122003');
      final second = await lookup.lookup('122003');

      expect(adapter.requests, hasLength(1));
      expect(second.status, PincodeLookupStatus.found);
    });

    test('a network failure is reported, not thrown, and not cached', () async {
      final adapter = _FakeAdapter(503, {'error': 'down'});
      final lookup = PostalPincodeLookup(
        dio: Dio()..httpClientAdapter = adapter,
      );

      final first = await lookup.lookup('122003');
      await lookup.lookup('122003');

      expect(first.status, PincodeLookupStatus.failed);
      expect(
        adapter.requests,
        hasLength(2),
        reason: 'a failure may succeed next time',
      );
    });
  });
}
