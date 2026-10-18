import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/domain/entities/cart_entities.dart';
import 'package:turquoise_delivery/features/cart/presentation/cart_screens.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/repositories/orders_repository_interface.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

const _bill = BillSummary(
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
);

class _Orders implements OrdersRepositoryInterface {
  final names = <String>[];

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
    double? expectedPayable,
  }) async {
    names.add(customerName);
    return Result.success(
      const PlacedOrder(
        orderId: '4242',
        orderNumber: 'ORD-4242',
        status: 'pending',
        bill: _bill,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Account implements AccountRepository {
  _Account({this.name = ''});

  String name;
  final updates = <String?>[];

  @override
  Future<CustomerProfile> fetchProfile() async =>
      CustomerProfile(id: 'u1', name: name, phone: '9876543210', email: '');

  @override
  Future<CustomerProfile> updateProfile({String? name, String? email}) async {
    updates.add(name);
    this.name = name ?? this.name;
    return CustomerProfile(
      id: 'u1',
      name: this.name,
      phone: '9876543210',
      email: '',
    );
  }

  @override
  Future<List<CustomerAddress>> fetchAddresses() async => const [
    CustomerAddress(
      id: 'a1',
      label: 'Home',
      addressLine1: '12 MG Road',
      area: 'Indiranagar',
      city: 'Bengaluru',
      pincode: '560038',
      latitude: 12.97,
      longitude: 77.64,
      isDefault: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  const item = CatalogItem(
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

  Future<(_Orders, _Account)> pump(
    WidgetTester tester, {
    String profileName = '',
    String storedName = '',
  }) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'auth_user_phone': '9876543210',
      if (storedName.isNotEmpty) 'auth_user_name': storedName,
    });
    final orders = _Orders();
    final account = _Account(name: profileName);
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/tracking/:id',
          builder: (_, _) => const Scaffold(body: Text('tracking')),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        cartBillProvider.overrideWith((ref) async => _bill),
        currentLocationProvider.overrideWith((ref) async => null),
        accountRepositoryProvider.overrideWithValue(account),
        placeOrderUseCaseProvider.overrideWithValue(PlaceOrderUseCase(orders)),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(cartControllerProvider.notifier)
        .addItem(item, restaurantId: '9');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (orders, account);
  }

  testWidgets('no name: Pay asks for it in one field, no error message', (
    tester,
  ) async {
    final (orders, account) = await pump(tester);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-name-field')), findsOneWidget);
    expect(find.textContaining('Please update your name'), findsNothing);
    expect(orders.names, isEmpty, reason: 'nothing is placed until a name is given');

    await tester.enterText(
      find.byKey(const Key('customer-name-field')),
      'Asha Rao',
    );
    await tester.tap(find.byKey(const Key('customer-name-save')));
    await tester.pumpAndSettle();

    expect(orders.names, ['Asha Rao'], reason: 'the order continues at once');
    expect(account.updates, ['Asha Rao'], reason: 'profile is updated too');
    expect(find.text('tracking'), findsOneWidget);
  });

  testWidgets('an empty name is refused inline and the sheet stays open', (
    tester,
  ) async {
    final (orders, _) = await pump(tester);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-name-save')));
    await tester.pump();

    expect(find.text('Please enter your name.'), findsOneWidget);
    expect(find.byKey(const Key('customer-name-field')), findsOneWidget);
    expect(orders.names, isEmpty);
  });

  testWidgets('a known name is never asked for again', (tester) async {
    final (orders, _) = await pump(tester, profileName: 'Asha Rao');

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-name-field')), findsNothing);
    expect(orders.names, ['Asha Rao']);
  });

  testWidgets('a name kept on the device counts as known', (tester) async {
    final (orders, _) = await pump(tester, storedName: 'Asha Rao');

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-name-field')), findsNothing);
    expect(orders.names, ['Asha Rao']);
  });
}
