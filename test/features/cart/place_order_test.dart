import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/cart/providers/checkout_view_model.dart';
import 'package:turquoise_delivery/features/cart/domain/entities/cart_entities.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/repositories/orders_repository_interface.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

class _FakeOrdersRepository implements OrdersRepositoryInterface {
  _FakeOrdersRepository({this.failure});

  /// When set, every call returns this failure instead of a placed order.
  final Failure? failure;

  int placeOrderCalls = 0;

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
    placeOrderCalls++;
    if (failure != null) return Result.failure(failure!);
    return Result.success(const PlacedOrder(
      orderId: '4242',
      orderNumber: 'ORD-4242',
      status: 'pending',
      bill: BillSummary(
        subtotal: 70, discount: 0, deliveryFee: 0, packagingCharge: 0,
        cgst: 0, sgst: 0, taxAmount: 0, platformFee: 0, roundOff: 0,
        grandTotal: 70, valid: true, message: '',
      ),
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

/// AccountRepository is a concrete class; the checkout path only calls these
/// two, and both are already wrapped in try/catch by the view model.
class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({this.name = 'Test Customer'});

  final String name;
  static const String phone = '9876543210';

  @override
  Future<CustomerProfile> fetchProfile() async =>
      CustomerProfile(id: 'u1', name: name, phone: phone, email: '');

  @override
  Future<List<CustomerAddress>> fetchAddresses() async => const [
        CustomerAddress(
          id: 'a1', label: 'Home', addressLine1: '12 MG Road', area: 'Indiranagar',
          city: 'Bengaluru', pincode: '560038', latitude: 12.97, longitude: 77.64,
          isDefault: true,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'auth_token': 'test-token',
        'auth_user_name': 'Test Customer',
        'auth_user_phone': '9876543210',
      }));

  CatalogItem foodItem() => const CatalogItem(
        id: 'item-1',
        name: 'Veg Roll',
        subtitle: '',
        store: 'Test Kitchen',
        price: 70,
        originalPrice: 70,
        imageUrl: '',
        type: CatalogItemType.food,
        storeId: '9',
      );

  ProviderContainer buildContainer(
    _FakeOrdersRepository repository, {
    _FakeAccountRepository? account,
    bool seedCart = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        // Location resolves to null: the saved address is enough to order.
        currentLocationProvider.overrideWith((ref) async {
          // A real GPS fix takes time; geolocator allows up to 12 s.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return null;
        }),
        accountRepositoryProvider
            .overrideWithValue(account ?? _FakeAccountRepository()),
        placeOrderUseCaseProvider
            .overrideWithValue(PlaceOrderUseCase(repository)),
      ],
    );
    if (seedCart) {
      container.read(cartControllerProvider.notifier).addItem(
            foodItem(),
            restaurantId: '9',
          );
    }
    return container;
  }

  test('COD checkout reaches the backend and returns a placed order', () async {
    final repository = _FakeOrdersRepository();
    final container = buildContainer(repository);
    addTearDown(container.dispose);

    final result = await container
        .read(checkoutViewModelProvider.notifier)
        .placeOrder(idempotencyKey: 'key-1', paymentMethod: 'cash');

    expect(repository.placeOrderCalls, 1,
        reason: 'the order must actually reach the repository');
    expect(result.isSuccess, isTrue);
  });

  test('a backend rejection is returned as a readable message', () async {
    final repository = _FakeOrdersRepository(
      failure: const ValidationFailure(
        'delivery address is 9.2 km away, max radius is 7 km',
      ),
    );
    final container = buildContainer(repository);
    addTearDown(container.dispose);

    final result = await container
        .read(checkoutViewModelProvider.notifier)
        .placeOrder(idempotencyKey: 'key-2', paymentMethod: 'cash');

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.message, contains('max radius is 7 km'));
  });

  test('a missing customer name is reported, and never reaches the backend',
      () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    final repository = _FakeOrdersRepository();
    final container = buildContainer(
      repository,
      account: _FakeAccountRepository(name: ''),
    );
    addTearDown(container.dispose);

    final result = await container
        .read(checkoutViewModelProvider.notifier)
        .placeOrder(idempotencyKey: 'key-3', paymentMethod: 'cash');

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.message, contains('name'));
    expect(repository.placeOrderCalls, 0);
  });

  // The profile endpoint returns empty strings for fields the customer has
  // not set. That must fall through to the stored session identity rather than
  // blocking checkout — `??` alone does not, since '' is not null.
  test('a blank profile name falls back to the stored session name', () async {
    final repository = _FakeOrdersRepository();
    final container = buildContainer(
      repository,
      account: _FakeAccountRepository(name: ''),
    );
    addTearDown(container.dispose);

    final result = await container
        .read(checkoutViewModelProvider.notifier)
        .placeOrder(idempotencyKey: 'key-5', paymentMethod: 'cash');

    expect(result.isSuccess, isTrue,
        reason: 'the stored name "Test Customer" should have been used');
    expect(repository.placeOrderCalls, 1);
  });

  test('an empty cart is reported, and never reaches the backend', () async {
    final repository = _FakeOrdersRepository();
    final container = buildContainer(repository, seedCart: false);
    addTearDown(container.dispose);

    final result = await container
        .read(checkoutViewModelProvider.notifier)
        .placeOrder(idempotencyKey: 'key-4', paymentMethod: 'cash');

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.message, contains('empty'));
    expect(repository.placeOrderCalls, 0);
  });
}
