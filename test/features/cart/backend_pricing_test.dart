import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/models/app_models.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  Map<String, dynamic> body;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': body}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SignedIn extends AppController {
  @override
  AppState build() => const AppState(authenticated: true);
}

const _item = CatalogItem(
  id: '42',
  name: 'Meal',
  subtitle: '',
  store: 'Kitchen',
  price: 1,
  originalPrice: 1,
  imageUrl: '',
  type: CatalogItemType.food,
  storeId: '9',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  (_Adapter, OrdersRepositoryImpl) setup(Map<String, dynamic> body) {
    final adapter = _Adapter(body);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    return (
      adapter,
      OrdersRepositoryImpl(ApiClient(userDio: dio, restaurantDio: dio)),
    );
  }

  test(
    'bill preserves decimals, separates fees and never sums final payable',
    () async {
      final (adapter, repository) = setup({
        'is_valid': true,
        'grand_total': 999,
        'customer_bill': {
          'subtotal': 100.25,
          'coupon_discount': 10.75,
          'discount_amount': 14.00,
          'offer_discount': 3.25,
          'delivery_fee': 20.25,
          'platform_fee': 2.50,
          'packaging_fee': 4.25,
          'additional_charges': 1.75,
          'tax_amount': 5.25,
          'round_off_amount': -0.25,
          'grand_total': 120.50,
          'fees': [
            {'title': 'Handling', 'amount': 1.25},
          ],
          'items': [
            {
              'item_id': 42,
              'quantity': 1,
              'selling_price': 100.25,
              'original_price': 110.75,
              'discount': 10.50,
              'line_total': 100.25,
            },
          ],
        },
      });
      final result = await repository.validateCart(
        restaurantId: '9',
        lines: const [
          CartLine(selection: CartSelection(item: _item), quantity: 1),
        ],
        couponCode: 'SAVE',
        deliveryLatitude: 28.44,
        deliveryLongitude: 77.05,
      );
      final bill = result.dataOrNull!;
      expect(bill.grandTotal, 120.50);
      expect(bill.subtotal, 100.25);
      expect(bill.packagingCharge, 4.25);
      expect(bill.additionalCharges, 1.75);
      expect(bill.discount, 10.75);
      expect(bill.offerDiscount, 3.25);
      expect(bill.taxAmount, 5.25);
      expect(bill.fees.single.amount, 1.25);
      expect(bill.items.single.originalPrice, 110.75);
      expect(bill.items.single.discount, 10.50);
      final payload = adapter.requests.single.data as Map;
      expect(payload['customer_location'], {
        'latitude': 28.44,
        'longitude': 77.05,
      });
      expect(payload['coupon_code'], 'SAVE');
      expect((payload['items'] as List).single, {'item_id': 42, 'quantity': 1});
    },
  );

  test(
    'missing, malformed and invalid totals cannot enable checkout',
    () async {
      for (final body in <Map<String, dynamic>>[
        {},
        {'grand_total': 'oops'},
        {'grand_total': -1},
        {'grand_total': 100, 'is_valid': false},
      ]) {
        final (_, repository) = setup(body);
        final result = await repository.validateCart(
          restaurantId: '9',
          lines: const [],
        );
        expect(result.dataOrNull!.valid, isFalse);
      }
    },
  );

  test('quote follows the saved address, coupon and cart changes', () async {
    final (adapter, repository) = setup({'is_valid': true, 'grand_total': 80});
    var latitude = 28.44;
    final container = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repository),
        appControllerProvider.overrideWith(_SignedIn.new),
        addressesProvider.overrideWith(
          (ref) async => [
            CustomerAddress(
              id: 'home',
              label: 'Home',
              addressLine1: '12 Road',
              area: '',
              city: '',
              pincode: '',
              latitude: latitude,
              longitude: 77.05,
              isDefault: true,
            ),
          ],
        ),
        currentLocationProvider.overrideWith(
          (ref) async => const UserLocation(latitude: 12.97, longitude: 77.64),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(cartControllerProvider.notifier)
        .addItem(_item, restaurantId: '9');
    await container.read(cartBillProvider.future);
    expect(adapter.requests.last.data['customer_location']['latitude'], 28.44);
    latitude = 28.45;
    container.invalidate(addressesProvider);
    await container.read(cartBillProvider.future);
    expect(adapter.requests.last.data['customer_location']['latitude'], 28.45);
    container.read(cartCouponProvider.notifier).setCode('SAVE');
    await container.read(cartBillProvider.future);
    expect(adapter.requests.last.data['coupon_code'], 'SAVE');
    container
        .read(cartControllerProvider.notifier)
        .addItem(_item, restaurantId: '9');
    await container.read(cartBillProvider.future);
    expect(adapter.requests.last.data['items'].single['quantity'], 2);
  });

  test(
    'placement sends expected amount and identifiers, never client fees',
    () async {
      final (adapter, repository) = setup({
        'order_id': 7,
        'grand_total': 123.45,
      });
      await repository.placeOrder(
        restaurantId: '9',
        lines: const [
          CartLine(selection: CartSelection(item: _item), quantity: 2),
        ],
        idempotencyKey: 'stable',
        customerName: 'Customer',
        customerPhone: '9876543210',
        deliveryAddressLine1: '12 Road',
        deliveryLatitude: 28.44,
        deliveryLongitude: 77.05,
        expectedPayable: 123.45,
        couponCode: 'SAVE',
      );
      final payload = adapter.requests.single.data as Map;
      expect(payload['expected_payable'], 123.45);
      expect(payload['coupon_code'], 'SAVE');
      expect(adapter.requests.single.headers['Idempotency-Key'], 'stable');
      for (final key in [
        'grand_total',
        'subtotal',
        'delivery_fee',
        'extra_charges',
        'discount_amount',
      ]) {
        expect(payload.containsKey(key), isFalse);
      }
      await repository.placeGroceryOrder(
        groceryMerchantId: '9',
        lines: const [],
        idempotencyKey: 'grocery',
        customerName: 'Customer',
        customerPhone: '9876543210',
        deliveryAddress: '12 Road',
        deliveryLatitude: 28.44,
        deliveryLongitude: 77.05,
        expectedPayable: 123.45,
      );
      expect(adapter.requests.last.data['expected_payable'], 123.45);
    },
  );
}
