import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/domain/entities/cart_entities.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/cart/providers/checkout_view_model.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/repositories/orders_repository_interface.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

/// Records the delivery details checkout sends.
class _RecordingOrdersRepository implements OrdersRepositoryInterface {
  final List<Map<String, Object?>> orders = [];

  @override
  Future<Result<PlacedOrder>> placeOrder({
    required String restaurantId,
    required List<CartLine> lines,
    required String idempotencyKey,
    required String customerName,
    required String customerPhone,
    required String deliveryAddressLine1,
    required double deliveryLatitude,
    required double deliveryLongitude,
    String? deliveryArea,
    String? deliveryCity,
    String? deliveryPincode,
    String? deliveryLandmark,
    String? paymentMethod,
    String? couponCode,
    String? instructions,
  }) async {
    orders.add({
      'line1': deliveryAddressLine1,
      'lat': deliveryLatitude,
      'lng': deliveryLongitude,
      'area': deliveryArea,
      'pincode': deliveryPincode,
      'landmark': deliveryLandmark,
    });
    return Result.success(
      const PlacedOrder(
        orderId: '1',
        orderNumber: 'ORD-1',
        status: 'pending',
        bill: BillSummary(
          subtotal: 70,
          discount: 0,
          deliveryFee: 0,
          packagingCharge: 0,
          cgst: 0,
          sgst: 0,
          taxAmount: 0,
          platformFee: 0,
          roundOff: 0,
          grandTotal: 70,
          valid: true,
          message: '',
        ),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Account implements AccountRepository {
  _Account(this.addresses);

  final List<CustomerAddress> addresses;

  @override
  Future<CustomerProfile> fetchProfile() async => const CustomerProfile(
    id: 'u1',
    name: 'Test Customer',
    phone: '9876543210',
    email: '',
  );

  @override
  Future<List<CustomerAddress>> fetchAddresses() async => addresses;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

const _home = CustomerAddress(
  id: 'home',
  label: 'Home',
  addressLine1: '108, Sector 49',
  area: 'Sector 49',
  landmark: 'Opposite the park',
  city: 'Gurgaon',
  pincode: '122003',
  isDefault: true,
  latitude: 28.4089,
  longitude: 77.0532,
);

const _office = UserLocation(latitude: 28.5355, longitude: 77.3910);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'auth_user_name': 'Test Customer',
      'auth_user_phone': '9876543210',
    }),
  );

  late int gpsReads;

  ProviderContainer build(
    _RecordingOrdersRepository orders,
    List<CustomerAddress> addresses, {
    UserLocation? device,
  }) {
    gpsReads = 0;
    final container = ProviderContainer(
      overrides: [
        currentLocationProvider.overrideWith((ref) async {
          gpsReads++;
          return device;
        }),
        accountRepositoryProvider.overrideWithValue(_Account(addresses)),
        placeOrderUseCaseProvider.overrideWithValue(PlaceOrderUseCase(orders)),
      ],
    );
    container
        .read(cartControllerProvider.notifier)
        .addItem(
          const CatalogItem(
            id: 'item-1',
            name: 'Veg Roll',
            subtitle: '',
            store: 'Test Kitchen',
            price: 70,
            originalPrice: 70,
            imageUrl: '',
            type: CatalogItemType.food,
            storeId: '9',
          ),
          restaurantId: '9',
        );
    return container;
  }

  Future<Result<PlacedOrder>> place(ProviderContainer container) => container
      .read(checkoutViewModelProvider.notifier)
      .placeOrder(idempotencyKey: 'k', paymentMethod: 'cash');

  // An order to "Home" placed from the office used to be pinned at the office.
  test('a pinned address is delivered to its own pin, not the phone', () async {
    final orders = _RecordingOrdersRepository();
    final container = build(orders, [_home], device: _office);
    addTearDown(container.dispose);

    final result = await place(container);

    expect(result.isSuccess, isTrue);
    expect(orders.orders.single['lat'], 28.4089);
    expect(orders.orders.single['lng'], 77.0532);
    expect(gpsReads, 0, reason: 'no GPS wait when the address has a pin');
  });

  test('the landmark field is sent as the landmark', () async {
    final orders = _RecordingOrdersRepository();
    final container = build(orders, [_home]);
    addTearDown(container.dispose);

    await place(container);

    expect(orders.orders.single['landmark'], 'Opposite the park');
    expect(orders.orders.single['area'], 'Sector 49');
  });

  test(
    'an address saved without a pin falls back to the phone location',
    () async {
      final orders = _RecordingOrdersRepository();
      const manual = CustomerAddress(
        id: 'm',
        label: 'Home',
        addressLine1: '12 MG Road',
        area: 'Indiranagar',
        city: 'Bengaluru',
        pincode: '560038',
        isDefault: true,
      );
      final container = build(orders, [manual], device: _office);
      addTearDown(container.dispose);

      final result = await place(container);

      expect(result.isSuccess, isTrue);
      expect(orders.orders.single['lat'], _office.latitude);
      expect(orders.orders.single['line1'], '12 MG Road');
    },
  );

  test(
    'no pin and no location blocks the order with a clear message',
    () async {
      final orders = _RecordingOrdersRepository();
      const manual = CustomerAddress(
        id: 'm',
        label: 'Home',
        addressLine1: '12 MG Road',
        area: 'Indiranagar',
        city: 'Bengaluru',
        pincode: '560038',
        isDefault: true,
      );
      final container = build(orders, [manual]);
      addTearDown(container.dispose);

      final result = await place(container);

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Use current location'));
      expect(orders.orders, isEmpty);
    },
  );

  // A "Current location" order has no house or flat for the rider.
  test('checkout needs a saved address, even with location on', () async {
    final orders = _RecordingOrdersRepository();
    final container = build(orders, const [], device: _office);
    addTearDown(container.dispose);

    final result = await place(container);

    expect(result.isFailure, isTrue);
    expect(
      result.failureOrNull?.message,
      'Add a delivery address to place your order.',
    );
    expect(orders.orders, isEmpty);
  });

  // "Deliver my orders here" makes the new address the default, which is the
  // address checkout uses.
  test('the address marked "deliver here" is the one ordered to', () async {
    final orders = _RecordingOrdersRepository();
    const older = CustomerAddress(
      id: 'old',
      label: 'Work',
      addressLine1: 'Tower B',
      area: 'Cyber City',
      city: 'Gurgaon',
      pincode: '122002',
      isDefault: false,
      latitude: 28.49,
      longitude: 77.08,
    );
    final container = build(orders, [older, _home]);
    addTearDown(container.dispose);

    await place(container);

    expect(orders.orders.single['line1'], '108, Sector 49');
  });
}
