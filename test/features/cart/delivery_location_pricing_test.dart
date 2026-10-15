import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/features/account/address/address_location_capture.dart';
import 'package:turquoise_delivery/features/account/address/address_providers.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/core/widgets/app_ui.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/domain/entities/cart_entities.dart';
import 'package:turquoise_delivery/features/cart/presentation/cart_screens.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/cart/providers/delivery_location.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/repositories/orders_repository_interface.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

const _home = CustomerAddress(
  id: 'home',
  label: 'Home',
  addressLine1: '108, Vijay Nagar',
  area: 'Vijay Nagar',
  city: 'Bijnor',
  pincode: '246722',
  isDefault: true,
  latitude: 29.3724,
  longitude: 78.1358,
);

const _work = CustomerAddress(
  id: 'work',
  label: 'Work',
  addressLine1: 'Tower B',
  area: 'Civil Lines',
  city: 'Bijnor',
  pincode: '246701',
  isDefault: true,
  latitude: 29.40,
  longitude: 78.20,
);

const _unpinned = CustomerAddress(
  id: 'legacy',
  label: 'Home',
  addressLine1: 'A',
  area: 'A',
  city: 'Bijnor',
  pincode: '246722',
  isDefault: true,
);

const _phone = UserLocation(latitude: 28.5355, longitude: 77.3910);

BillSummary _bill(double deliveryFee) => BillSummary(
  subtotal: 70,
  discount: 0,
  deliveryFee: deliveryFee,
  packagingCharge: 0,
  cgst: 0,
  sgst: 0,
  taxAmount: 0,
  platformFee: 0,
  roundOff: 0,
  grandTotal: 70 + deliveryFee,
  valid: true,
  message: '',
);

/// Stands in for restaurant-service: records the pin it is priced from and
/// answers with a scripted result.
class _Pricing implements OrdersRepositoryInterface {
  final calls = <(double?, double?)>[];
  Result<BillSummary> Function(double? lat, double? lng)? script;

  @override
  Future<Result<BillSummary>> validateCart({
    required String restaurantId,
    required List<CartLine> lines,
    String? couponCode,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    calls.add((deliveryLatitude, deliveryLongitude));
    return script?.call(deliveryLatitude, deliveryLongitude) ??
        Result.success(_bill(25));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Account implements AccountRepository {
  _Account(this.addresses);

  List<CustomerAddress> addresses;
  final updated = <CustomerAddress>[];

  @override
  Future<List<CustomerAddress>> fetchAddresses() async => addresses;

  @override
  Future<CustomerAddress> updateAddress(
    String id,
    CustomerAddress address,
  ) async {
    updated.add(address);
    addresses = [address];
    return address;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Capture implements AddressLocationCapture {
  _Capture(this.result);

  final LocationCaptureResult result;
  int calls = 0;

  @override
  Future<LocationCaptureResult> capture() async {
    calls++;
    return result;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _SignedIn extends AppController {
  @override
  AppState build() => const AppState(authenticated: true, sessionLoaded: true);
}

const _item = CatalogItem(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Pricing pricing;
  late _Account account;
  late int gpsReads;

  ProviderContainer build({
    List<CustomerAddress> addresses = const [_home],
    UserLocation? device = _phone,
    List<Override> extra = const [],
  }) {
    pricing = _Pricing();
    account = _Account(addresses);
    gpsReads = 0;
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(_SignedIn.new),
        accountRepositoryProvider.overrideWithValue(account),
        currentLocationProvider.overrideWith((ref) async {
          gpsReads++;
          return device;
        }),
        validateCartUseCaseProvider.overrideWithValue(
          ValidateCartUseCase(pricing),
        ),
        ...extra,
      ],
    );
    container
        .read(cartControllerProvider.notifier)
        .addItem(_item, restaurantId: '9');
    addTearDown(container.dispose);
    return container;
  }

  group('CustomerAddress', () {
    test('only a finite, in-range, non-zero pair is a usable pin', () {
      CustomerAddress at(double? lat, double? lng) => CustomerAddress(
        id: 'a',
        label: 'Home',
        addressLine1: 'x',
        area: '',
        city: '',
        pincode: '',
        isDefault: true,
        latitude: lat,
        longitude: lng,
      );
      expect(at(29.37, 78.13).hasPin, isTrue);
      expect(at(null, null).hasPin, isFalse);
      expect(at(29.37, null).hasPin, isFalse);
      expect(at(0, 0).hasPin, isFalse);
      expect(at(91, 10).hasPin, isFalse);
      expect(at(10, 181).hasPin, isFalse);
      expect(at(double.nan, 10).hasPin, isFalse);
      expect(at(null, null).needsLocationConfirmation, isTrue);
    });

    test('latitude/longitude parse from every API spelling and strings', () {
      CustomerAddress parse(Map<String, dynamic> pin) =>
          CustomerAddress.fromJson({
            'id': 'a',
            'label': 'Home',
            'address_line1': 'x',
            'pincode': '246722',
            ...pin,
          });
      expect(parse({'latitude': 29.37, 'longitude': 78.13}).hasPin, isTrue);
      expect(parse({'lat': 29.37, 'lng': 78.13}).hasPin, isTrue);
      expect(parse({'lat': '29.37', 'lon': '78.13'}).hasPin, isTrue);
      expect(parse({'latitude': '', 'longitude': ''}).hasPin, isFalse);
      expect(parse({'latitude': 0, 'longitude': 0}).hasPin, isFalse);
      expect(parse(const {}).hasPin, isFalse);
    });

    test('the pin survives a round trip through toJson', () {
      final json = _home.toJson();
      final again = CustomerAddress.fromJson(json);
      expect(again.latitude, _home.latitude);
      expect(again.longitude, _home.longitude);
      expect(_unpinned.toJson().containsKey('latitude'), isFalse);
    });

    test('formatted text drops blanks and repeats and invents nothing', () {
      expect(_unpinned.singleLine, 'A, Bijnor, 246722');
      const sparse = CustomerAddress(
        id: 's',
        label: 'Home',
        addressLine1: 'Vijay Nagar',
        area: '',
        city: 'Bijnor',
        state: 'Uttar Pradesh',
        pincode: '246722',
        isDefault: true,
      );
      expect(sparse.singleLine, 'Vijay Nagar, Bijnor, Uttar Pradesh, 246722');
    });

    test('adding a pin keeps every typed field', () {
      final fixed = _unpinned.withPin(latitude: 29.37, longitude: 78.13);
      expect(fixed.hasPin, isTrue);
      expect(fixed.addressLine1, 'A');
      expect(fixed.label, 'Home');
      expect(fixed.id, 'legacy');
    });
  });

  group('chooseDeliveryLocation', () {
    test('a pinned saved address wins over the device location', () {
      final state = chooseDeliveryLocation(
        addresses: const [_home],
        device: _phone,
      );
      final resolved = state as DeliveryLocationResolved;
      expect(resolved.location.latitude, _home.latitude);
      expect(resolved.location.source, DeliveryLocationSource.savedAddress);
      expect(resolved.location.label, 'Home');
    });

    test('an unpinned address is never replaced by the device location', () {
      final state = chooseDeliveryLocation(
        addresses: const [_unpinned],
        device: _phone,
      );
      expect(state, isA<DeliveryLocationNeedsConfirmation>());
    });

    test('no address uses the device location, else nothing', () {
      final live = chooseDeliveryLocation(addresses: const [], device: _phone);
      expect(
        (live as DeliveryLocationResolved).location.source,
        DeliveryLocationSource.currentLocation,
      );
      expect(
        chooseDeliveryLocation(addresses: const [], device: null),
        isA<DeliveryLocationUnavailable>(),
      );
    });

    test('the default address is the selected one', () {
      const other = CustomerAddress(
        id: 'o',
        label: 'Other',
        addressLine1: 'y',
        area: '',
        city: '',
        pincode: '',
        isDefault: false,
        latitude: 1,
        longitude: 2,
      );
      final state = chooseDeliveryLocation(
        addresses: const [other, _work],
        device: null,
      );
      expect((state as DeliveryLocationResolved).location.id, 'work');
    });
  });

  group('typed pricing failures', () {
    DeliveryPricingFailure fromBody(String? status, {String? code}) {
      final failure = Failure.fromApiException(
        ApiException(
          statusCode: 400,
          message:
              'We couldn\'t calculate the delivery charge for this order. '
              'Please confirm your delivery address and try again.',
          code: code ?? 'DELIVERY_PRICING_UNAVAILABLE',
          data: status == null ? null : {'pricing_status': status},
        ),
      );
      return failure as DeliveryPricingFailure;
    }

    test('MISSING_CUSTOMER_LOCATION asks to confirm the location', () {
      final f = fromBody('MISSING_CUSTOMER_LOCATION');
      expect(f.message, 'Please confirm your delivery location.');
      expect(f.status.addressCanFix, isTrue);
    });

    test('MISSING_RESTAURANT_LOCATION does not blame the address', () {
      final f = fromBody('MISSING_RESTAURANT_LOCATION');
      expect(
        f.message,
        'Delivery is temporarily unavailable for this restaurant.',
      );
      expect(f.status.addressCanFix, isFalse);
      expect(f.message.toLowerCase(), isNot(contains('address')));
    });

    test('NO_MATCHING_RULE says the location is outside the area', () {
      final f = fromBody('NO_MATCHING_RULE');
      expect(f.message, 'This location is outside the current delivery area.');
      expect(f.status.addressCanFix, isTrue);
    });

    test('PRICING_UNAVAILABLE is a plain retry', () {
      final f = fromBody('PRICING_UNAVAILABLE');
      expect(
        f.message,
        "We couldn't calculate the delivery charge. Please try again.",
      );
      expect(f.status.retryable, isTrue);
    });

    test('out of range code gets its own message', () {
      final f = Failure.fromApiException(
        const ApiException(
          statusCode: 400,
          message:
              'This restaurant does not deliver to your selected location.',
          code: 'DELIVERY_OUT_OF_RANGE',
        ),
      );
      expect(
        (f as DeliveryPricingFailure).message,
        'Delivery is not available for this location.',
      );
    });

    test('an older backend without a status still maps to a neutral retry', () {
      final f = fromBody(null);
      expect(f.status, DeliveryPricingStatus.pricingUnavailable);
      expect(f.message.toLowerCase(), isNot(contains('address')));
    });

    test('unrelated 400s stay ordinary validation failures', () {
      final f = Failure.fromApiException(
        const ApiException(statusCode: 400, message: 'Coupon expired'),
      );
      expect(f, isA<ValidationFailure>());
    });
  });

  group('cart bill', () {
    test('prices from the saved Home pin and never reads GPS', () async {
      final container = build();
      final bill = await container.read(cartBillProvider.future);

      expect(bill.deliveryFee, 25);
      expect(pricing.calls.single, (_home.latitude, _home.longitude));
      expect(gpsReads, 0, reason: 'saved address needs no GPS permission');
    });

    test(
      'an unpinned address asks for confirmation and sends nothing',
      () async {
        final container = build(addresses: const [_unpinned]);

        await expectLater(
          container.read(cartBillProvider.future),
          throwsA(isA<DeliveryLocationRequired>()),
        );
        expect(pricing.calls, isEmpty, reason: 'no request without a pin');
        expect(gpsReads, 0, reason: 'GPS is not substituted for the address');
      },
    );

    test('no address and no location asks for an address', () async {
      final container = build(addresses: const [], device: null);

      await expectLater(
        container.read(cartBillProvider.future),
        throwsA(
          isA<DeliveryLocationRequired>().having(
            (e) => e.address,
            'address',
            isNull,
          ),
        ),
      );
      expect(pricing.calls, isEmpty);
    });

    test('changing the address re-prices from the new pin', () async {
      final container = build();
      pricing.script = (lat, lng) =>
          Result.success(_bill(lat! > 29.39 ? 60 : 25));

      final first = await container.read(cartBillProvider.future);
      expect(first.deliveryFee, 25);

      account.addresses = const [_work];
      container.invalidate(addressesProvider);
      final second = await container.read(cartBillProvider.future);

      expect(second.deliveryFee, 60, reason: 'no stale fee from Home');
      expect(pricing.calls.last, (_work.latitude, _work.longitude));
    });

    test('an explicit free delivery is a valid bill', () async {
      final container = build();
      pricing.script = (_, _) => Result.success(_bill(0));

      final bill = await container.read(cartBillProvider.future);

      expect(bill.valid, isTrue);
      expect(bill.deliveryFee, 0);
    });

    test('a refusal never becomes a bill', () async {
      final container = build();
      pricing.script = (_, _) => Result.failure(
        const DeliveryPricingFailure(
          DeliveryPricingStatus.noMatchingRule,
          statusCode: 400,
        ),
      );

      await expectLater(
        container.read(cartBillProvider.future),
        throwsA(isA<DeliveryPricingFailure>()),
      );
    });

    test('retry after a failure prices from the current location', () async {
      final container = build();
      var attempt = 0;
      pricing.script = (_, _) {
        attempt++;
        return attempt == 1
            ? Result.failure(
                const DeliveryPricingFailure(
                  DeliveryPricingStatus.pricingUnavailable,
                  statusCode: 400,
                ),
              )
            : Result.success(_bill(30));
      };

      await expectLater(
        container.read(cartBillProvider.future),
        throwsA(isA<DeliveryPricingFailure>()),
      );
      container.invalidate(cartBillProvider);
      final bill = await container.read(cartBillProvider.future);

      expect(bill.deliveryFee, 30);
    });
  });

  group('cart screen', () {
    Future<ProviderContainer> showCart(
      WidgetTester tester, {
      required Object? error,
      List<CustomerAddress> addresses = const [_home],
      BillSummary? bill,
      AddressLocationCapture? capture,
    }) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = build(
        addresses: addresses,
        extra: [
          if (capture != null)
            addressLocationCaptureProvider.overrideWithValue(capture),
          addressesProvider.overrideWith((ref) async => addresses),
          cartBillProvider.overrideWith((ref) async {
            if (bill != null) return bill;
            throw error!;
          }),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const CartScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    bool checkoutEnabled(WidgetTester tester) {
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Proceed to checkout'),
      );
      return button.onPressed != null;
    }

    testWidgets('an unpinned Home asks for confirmation, not a price', (
      tester,
    ) async {
      await showCart(
        tester,
        error: const DeliveryLocationRequired(_unpinned),
        addresses: const [_unpinned],
      );

      expect(find.text('Location confirmation required'), findsOneWidget);
      expect(find.text('A, Bijnor, 246722'), findsOneWidget);
      expect(
        find.byKey(const Key('pricing-use-current-location')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pricing-change-address')), findsOneWidget);
      expect(find.text('Delivery unavailable'), findsOneWidget);
      expect(checkoutEnabled(tester), isFalse);
    });

    testWidgets('restaurant location missing does not blame the address', (
      tester,
    ) async {
      await showCart(
        tester,
        error: const DeliveryPricingFailure(
          DeliveryPricingStatus.missingRestaurantLocation,
        ),
      );

      expect(
        find.text('Delivery is temporarily unavailable for this restaurant.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pricing-change-address')), findsNothing);
      expect(find.byKey(const Key('pricing-retry')), findsOneWidget);
      expect(checkoutEnabled(tester), isFalse);
    });

    testWidgets('no matching slab offers a change of address', (tester) async {
      await showCart(
        tester,
        error: const DeliveryPricingFailure(
          DeliveryPricingStatus.noMatchingRule,
        ),
      );

      expect(
        find.text('This location is outside the current delivery area.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pricing-change-address')), findsOneWidget);
      expect(checkoutEnabled(tester), isFalse);
    });

    testWidgets('a failed bill shows menu prices, not "Updating price"', (
      tester,
    ) async {
      await showCart(
        tester,
        error: const DeliveryPricingFailure(
          DeliveryPricingStatus.pricingUnavailable,
        ),
      );

      expect(find.text('Updating price…'), findsNothing);
      expect(find.text('Menu price ₹70'), findsOneWidget);
      expect(find.text('Items ₹70 at menu prices'), findsOneWidget);
    });

    testWidgets('a good bill enables checkout', (tester) async {
      await showCart(tester, error: null, bill: _bill(25));

      expect(find.text('₹95'), findsWidgets);
      expect(checkoutEnabled(tester), isTrue);
    });

    testWidgets('confirming with current location pins the saved address', (
      tester,
    ) async {
      final capture = _Capture(
        LocationCaptureResult.captured(
          CapturedLocation(
            latitude: 29.3724,
            longitude: 78.1358,
            accuracyMeters: 12,
            capturedAt: DateTime(2026, 10, 15),
          ),
        ),
      );
      await showCart(
        tester,
        error: const DeliveryLocationRequired(_unpinned),
        addresses: const [_unpinned],
        capture: capture,
      );

      await tester.tap(find.byKey(const Key('pricing-use-current-location')));
      await tester.pumpAndSettle();
      expect(find.text('Use your current location?'), findsOneWidget);
      expect(capture.calls, 0, reason: 'nothing is read before confirming');

      await tester.tap(
        find.widgetWithText(FilledButton, 'Use current location').last,
      );
      await tester.pumpAndSettle();

      expect(capture.calls, 1);
      final saved = account.updated.single;
      expect(saved.id, 'legacy');
      expect(saved.latitude, 29.3724);
      expect(saved.longitude, 78.1358);
      expect(saved.addressLine1, 'A', reason: 'typed text is kept as typed');
    });

    testWidgets('a denied permission saves nothing and explains why', (
      tester,
    ) async {
      final capture = _Capture(
        const LocationCaptureResult.failed(
          LocationCaptureFailure.permissionDenied,
        ),
      );
      await showCart(
        tester,
        error: const DeliveryLocationRequired(_unpinned),
        addresses: const [_unpinned],
        capture: capture,
      );

      await tester.tap(find.byKey(const Key('pricing-use-current-location')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Use current location').last,
      );
      await tester.pumpAndSettle();

      expect(account.updated, isEmpty);
      expect(find.textContaining('Location permission is off'), findsOneWidget);
    });
  });
}
