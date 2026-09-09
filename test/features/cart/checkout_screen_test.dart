import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';
import 'package:turquoise_delivery/core/error/result.dart';
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
  subtotal: 70, discount: 0, deliveryFee: 0, packagingCharge: 0,
  cgst: 0, sgst: 0, taxAmount: 0, platformFee: 0, roundOff: 0,
  grandTotal: 70, valid: true, message: '',
);

class _FakeOrdersRepository implements OrdersRepositoryInterface {
  _FakeOrdersRepository({this.failure, this.delay = Duration.zero});

  final Failure? failure;
  final Duration delay;
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
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) return Result.failure(failure!);
    return Result.success(const PlacedOrder(
      orderId: '4242', orderNumber: 'ORD-4242', status: 'pending', bill: _bill,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeAccountRepository implements AccountRepository {
  @override
  Future<CustomerProfile> fetchProfile() async => const CustomerProfile(
        id: 'u1', name: 'Test Customer', phone: '9876543210', email: '',
      );

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

  const item = CatalogItem(
    id: 'item-1', name: 'Veg Roll', subtitle: '', store: 'Test Kitchen',
    price: 70, originalPrice: 70, imageUrl: '',
    type: CatalogItemType.food, storeId: '9',
  );

  /// Pumps the real CheckoutScreen behind a router, so a successful order can
  /// actually navigate to /tracking/:id the way it does in the app.
  Future<String> pumpCheckout(
    WidgetTester tester,
    _FakeOrdersRepository repository,
  ) async {
    var location = '/checkout';
    final router = GoRouter(
      initialLocation: '/checkout',
      routes: [
        GoRoute(
          path: '/checkout',
          builder: (_, _) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/tracking/:id',
          builder: (_, state) {
            location = '/tracking/${state.pathParameters['id']}';
            return const Scaffold(body: Text('tracking'));
          },
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        cartBillProvider.overrideWith((ref) async => _bill),
        currentLocationProvider.overrideWith((ref) async {
          // A real GPS fix is not instant; this is what disposed the
          // checkout notifier mid-flight before the fix.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return null;
        }),
        accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
        placeOrderUseCaseProvider
            .overrideWithValue(PlaceOrderUseCase(repository)),
      ],
    );
    addTearDown(container.dispose);
    // Seed before the first frame: mutating a provider during build is illegal.
    container.read(cartControllerProvider.notifier)
        .addItem(item, restaurantId: '9');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return location;
  }

  /// The button widget itself, which stays in the tree while loading (the
  /// label is swapped for a spinner), so a double tap can still be delivered.
  Finder payButton() => find.byType(AppButton);

  /// The idle label, absent while the order is in flight.
  Finder payLabel() => find.textContaining('Pay ₹');

  testWidgets('tapping Pay shows a spinner and lands on order tracking',
      (tester) async {
    final repository = _FakeOrdersRepository(
      delay: const Duration(milliseconds: 50),
    );
    await pumpCheckout(tester, repository);

    expect(payLabel(), findsOneWidget);
    await tester.tap(payButton());
    await tester.pump();

    // Loading state is visible while the order is in flight.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(repository.placeOrderCalls, 1);
    expect(find.text('tracking'), findsOneWidget);
  });

  testWidgets('a backend failure shows a snackbar and re-enables the button',
      (tester) async {
    final repository = _FakeOrdersRepository(
      delay: const Duration(milliseconds: 20),
      failure: const ValidationFailure('restaurant is not active'),
    );
    await pumpCheckout(tester, repository);

    await tester.tap(payButton());
    await tester.pumpAndSettle();

    expect(find.text('restaurant is not active'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Still on checkout, and tappable again.
    expect(payLabel(), findsOneWidget);
  });

  testWidgets('a rapid double tap places exactly one order', (tester) async {
    final repository = _FakeOrdersRepository(
      delay: const Duration(milliseconds: 80),
    );
    await pumpCheckout(tester, repository);

    await tester.tap(payButton(), warnIfMissed: false);
    await tester.tap(payButton(), warnIfMissed: false);
    await tester.pump();
    await tester.tap(payButton(), warnIfMissed: false);

    await tester.pumpAndSettle();
    expect(repository.placeOrderCalls, 1,
        reason: 'double-submit must never create a second order');
  });
}
