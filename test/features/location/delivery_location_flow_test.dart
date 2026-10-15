import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turquoise_delivery/app/theme/app_theme.dart';
import 'package:turquoise_delivery/core/error/failures.dart';
import 'package:turquoise_delivery/core/error/result.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/core/services/location_service.dart';
import 'package:turquoise_delivery/core/services/reverse_geocoding_service.dart';
import 'package:turquoise_delivery/features/account/address/address_form_sheet.dart';
import 'package:turquoise_delivery/features/account/address/address_location_capture.dart';
import 'package:turquoise_delivery/features/account/address/address_providers.dart';
import 'package:turquoise_delivery/features/account/address/pincode_lookup.dart';
import 'package:turquoise_delivery/features/app_state/providers/app_controller.dart';
import 'package:turquoise_delivery/features/app_state/providers/location_providers.dart';
import 'package:turquoise_delivery/features/cart/domain/entities/cart_entities.dart';
import 'package:turquoise_delivery/features/cart/presentation/cart_screens.dart';
import 'package:turquoise_delivery/features/cart/presentation/complete_delivery_address_sheet.dart';
import 'package:turquoise_delivery/features/cart/providers/cart_controller.dart';
import 'package:turquoise_delivery/features/cart/providers/delivery_location.dart';
import 'package:turquoise_delivery/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:turquoise_delivery/features/catalog/domain/entities/catalog_entities.dart';
import 'package:turquoise_delivery/features/catalog/providers/catalog_providers.dart';
import 'package:turquoise_delivery/features/orders/domain/entities/order_entities.dart';
import 'package:turquoise_delivery/features/orders/domain/repositories/orders_repository_interface.dart';
import 'package:turquoise_delivery/features/orders/domain/use_cases/orders_use_cases.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/formatting/distance_format.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';
import 'package:turquoise_delivery/shared/repositories/json_readers.dart';

// ---- fixtures ---------------------------------------------------------------

const _bijnor = UserLocation(latitude: 29.3724, longitude: 78.1358);

const _bijnorAddress = PlaceAddress(
  sublocality: 'Vijay Nagar',
  locality: 'Bijnor',
  district: 'Bijnor',
  state: 'Uttar Pradesh',
  postalCode: '246722',
);

const _home = CustomerAddress(
  id: 'home',
  label: 'Home',
  addressLine1: '42, Vijay Nagar',
  area: 'Vijay Nagar',
  city: 'Bijnor',
  state: 'Uttar Pradesh',
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
  isDefault: false,
  latitude: 29.40,
  longitude: 78.20,
);

const _unpinned = CustomerAddress(
  id: 'legacy',
  label: 'Home',
  addressLine1: 'House 9',
  area: 'Old Town',
  city: 'Bijnor',
  pincode: '246701',
  isDefault: true,
);

class _Gps extends LocationService {
  _Gps(this.result, {this.failure});

  final UserLocation? result;
  final LocationException? failure;
  int calls = 0;

  @override
  Future<UserLocation> current({bool prompt = true}) async {
    calls++;
    if (failure != null) throw failure!;
    return result!;
  }
}

class _Geocoder implements ReverseGeocoder {
  _Geocoder({this.address, this.fails = false});

  PlaceAddress? address;
  bool fails;
  final points = <(double, double)>[];

  @override
  Future<PlaceAddress?> reverse(double latitude, double longitude) async {
    points.add((latitude, longitude));
    if (fails) throw StateError('geocoder offline');
    return address;
  }
}

class _Account implements AccountRepository {
  _Account([List<CustomerAddress>? addresses])
    : addresses = addresses ?? <CustomerAddress>[];

  List<CustomerAddress> addresses;
  final added = <CustomerAddress>[];
  final defaults = <String>[];

  @override
  Future<List<CustomerAddress>> fetchAddresses() async => List.of(addresses);

  @override
  Future<CustomerAddress> addAddress(CustomerAddress address) async {
    added.add(address);
    final saved = CustomerAddress(
      id: 'new-${added.length}',
      label: address.label,
      addressLine1: address.addressLine1,
      area: address.area,
      city: address.city,
      state: address.state,
      pincode: address.pincode,
      isDefault: address.isDefault,
      latitude: address.latitude,
      longitude: address.longitude,
      landmark: address.landmark,
      district: address.district,
      receiverName: address.receiverName,
    );
    addresses = [saved, ...addresses.map((a) => a)];
    return saved;
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    defaults.add(id);
    addresses = [
      for (final a in addresses)
        CustomerAddress(
          id: a.id,
          label: a.label,
          addressLine1: a.addressLine1,
          area: a.area,
          city: a.city,
          state: a.state,
          pincode: a.pincode,
          isDefault: a.id == id,
          latitude: a.latitude,
          longitude: a.longitude,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _SignedOut extends AppController {
  @override
  AppState build() => const AppState(sessionLoaded: true);
}

class _SignedIn extends AppController {
  @override
  AppState build() => const AppState(authenticated: true, sessionLoaded: true);
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.data);
  final Map<String, dynamic> data;
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(CatalogRepositoryImpl, _StubAdapter) _catalogServing(
  Map<String, dynamic> data,
) {
  final adapter = _StubAdapter(data);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  return (
    CatalogRepositoryImpl(ApiClient(restaurantDio: dio, userDio: dio)),
    adapter,
  );
}

/// Stands in for restaurant-service pricing; records the pin it is asked for.
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

class _Capture implements AddressLocationCapture {
  _Capture(this.result);
  final LocationCaptureResult result;

  @override
  Future<LocationCaptureResult> capture() async => result;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _NoPincode implements PincodeLookup {
  @override
  Future<PincodeLookupResult> lookup(String pincode) async =>
      const PincodeLookupResult.notFound();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ---------------------------------------------------------------------------
  group('reverse geocoder result cleaning', () {
    test('an Android-style placemark fills area, city, state and pincode', () {
      final address = placeAddressFromPlacemarks(const [
        RawPlacemark(
          name: '4HQQ+7M',
          thoroughfare: 'Station Road',
          subLocality: 'Vijay Nagar',
          locality: 'Bijnor',
          subAdministrativeArea: 'Bijnor',
          administrativeArea: 'Uttar Pradesh',
          postalCode: '246722',
          country: 'India',
        ),
      ])!;
      expect(address.area, 'Vijay Nagar');
      expect(address.city, 'Bijnor');
      expect(address.state, 'Uttar Pradesh');
      expect(address.postalCode, '246722');
      expect(address.primaryLabel, 'Vijay Nagar');
      expect(address.secondaryLabel, 'Bijnor, Uttar Pradesh');
    });

    test('placeholders, plus codes and repeats never reach the address', () {
      final address = placeAddressFromPlacemarks(const [
        RawPlacemark(
          street: 'Unnamed Road',
          subLocality: 'A',
          locality: 'A',
          subAdministrativeArea: 'a',
          administrativeArea: 'Uttar Pradesh',
          postalCode: 'null',
          country: 'India',
        ),
      ])!;
      // "A, A, A" collapses to one A; the bad pincode and road are dropped.
      expect(address.formatted, 'A, Uttar Pradesh');
      expect(address.postalCode, '');
      expect(address.street, '');
    });

    test('primary label falls back sublocality -> locality -> district', () {
      expect(const PlaceAddress(locality: 'Bijnor').primaryLabel, 'Bijnor');
      expect(
        const PlaceAddress(district: 'Bijnor District').primaryLabel,
        'Bijnor District',
      );
      expect(
        const PlaceAddress(
          neighborhood: 'Hill Colony',
          sublocality: 'Vijay Nagar',
        ).primaryLabel,
        'Hill Colony',
      );
    });

    test('a result with nothing meaningful is not an address', () {
      expect(
        placeAddressFromPlacemarks(const [
          RawPlacemark(name: 'Unnamed Road', country: 'India'),
        ]),
        isNull,
      );
    });

    test('an invalid pincode is dropped, not shown', () {
      final address = placeAddressFromPlacemarks(const [
        RawPlacemark(locality: 'Bijnor', postalCode: '12345'),
      ])!;
      expect(address.postalCode, '');
    });
  });

  // ---------------------------------------------------------------------------
  group('distance', () {
    test('a missing distance is null, never 0', () {
      expect(readDistanceKm(const {'name': 'X'}), isNull);
      expect(readDistanceKm(const {'distance_km': null}), isNull);
      expect(readDistanceKm(const {'distance': 'far'}), isNull);
      expect(readDistanceKm(const {'distance_km': -3}), isNull);
    });

    test('numbers and units are read as kilometres', () {
      expect(readDistanceKm(const {'distance_km': 1.84}), 1.84);
      expect(readDistanceKm(const {'distance': '850 m'}), closeTo(0.85, 1e-9));
      expect(readDistanceKm(const {'distance': '1.2 km'}), 1.2);
      expect(readDistanceKm(const {'distance_km': '4.2'}), 4.2);
    });

    test('a genuine zero stays zero', () {
      expect(readDistanceKm(const {'distance_km': 0}), 0);
    });

    test('formatting: metres under a kilometre, never "0 km" for 40 m', () {
      expect(formatDistanceKm(null), isNull);
      expect(formatDistanceKm(double.nan), isNull);
      expect(formatDistanceKm(0.04), '40 m');
      expect(formatDistanceKm(0.0), '0 m');
      expect(formatDistanceKm(0.45), '450 m');
      expect(formatDistanceKm(1.84), '1.8 km');
      expect(formatDistanceKm(4.2), '4.2 km');
      expect(formatDistanceKm(2.0), '2 km');
    });
  });

  // ---------------------------------------------------------------------------
  group('selection rule', () {
    test('no saved address: the device location is the delivery location', () {
      final state = chooseDeliveryLocation(addresses: const [], device: _bijnor);
      expect(state, isA<DeliveryLocationResolved>());
      final location = (state as DeliveryLocationResolved).location;
      expect(location.source, DeliveryLocationSource.currentLocation);
      expect(location.latitude, _bijnor.latitude);
    });

    test('no saved address and no device location is unavailable', () {
      expect(
        chooseDeliveryLocation(addresses: const [], device: null),
        isA<DeliveryLocationUnavailable>(),
      );
    });

    test('a (0,0) or NaN device fix is never a location', () {
      for (final bad in const [
        UserLocation(latitude: 0, longitude: 0),
        UserLocation(latitude: double.nan, longitude: 77),
      ]) {
        expect(
          chooseDeliveryLocation(addresses: const [], device: bad),
          isA<DeliveryLocationUnavailable>(),
        );
      }
    });

    test('a pinned default address wins over the device', () {
      final state = chooseDeliveryLocation(
        addresses: const [_home],
        device: const UserLocation(latitude: 28.5, longitude: 77.3),
      );
      final location = (state as DeliveryLocationResolved).location;
      expect(location.source, DeliveryLocationSource.savedAddress);
      expect(location.latitude, _home.latitude);
    });

    test('choosing current location overrides the saved address', () {
      final state = chooseDeliveryLocation(
        addresses: const [_home],
        device: const UserLocation(latitude: 28.5, longitude: 77.3),
        useCurrentLocation: true,
      );
      final location = (state as DeliveryLocationResolved).location;
      expect(location.source, DeliveryLocationSource.currentLocation);
      expect(location.latitude, 28.5);
    });

    test('an unpinned address needs confirmation and is never priced', () {
      final state = chooseDeliveryLocation(
        addresses: const [_unpinned],
        device: _bijnor,
      );
      expect(state, isA<DeliveryLocationNeedsConfirmation>());
    });

    test('current location chosen but no fix falls back to the address', () {
      final state = chooseDeliveryLocation(
        addresses: const [_home],
        device: null,
        useCurrentLocation: true,
      );
      expect(state, isA<DeliveryLocationResolved>());
      expect(
        (state as DeliveryLocationResolved).location.source,
        DeliveryLocationSource.savedAddress,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('canonical location providers', () {
    ProviderContainer build({
      List<CustomerAddress> addresses = const [],
      bool signedIn = false,
      UserLocation? fix = _bijnor,
      LocationException? gpsFailure,
      _Geocoder? geocoder,
      _Gps? gps,
      List<Override> extra = const [],
    }) {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appControllerProvider.overrideWith(
            signedIn ? _SignedIn.new : _SignedOut.new,
          ),
          accountRepositoryProvider.overrideWithValue(_Account(addresses)),
          locationServiceProvider.overrideWithValue(
            gps ?? _Gps(fix, failure: gpsFailure),
          ),
          reverseGeocoderProvider.overrideWithValue(
            geocoder ?? _Geocoder(address: _bijnorAddress),
          ),
          ...extra,
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('fresh install: GPS -> geocode -> real locality in the header', () async {
      final geocoder = _Geocoder(address: _bijnorAddress);
      final container = build(geocoder: geocoder);
      // Keep the providers alive like a mounted header would.
      container.listen(deliveryLocationViewProvider, (_, _) {});

      await container.read(deliveryLocationProvider.future);
      await container.read(deviceAddressProvider.future);

      final view = container.read(deliveryLocationViewProvider);
      expect(view.phase, DeliveryLocationPhase.ready);
      expect(view.primary, 'Vijay Nagar');
      expect(view.secondary, 'Bijnor, Uttar Pradesh');
      expect(view.primary, isNot('Current location'));
      expect(geocoder.points.single, (_bijnor.latitude, _bijnor.longitude));
    });

    test('geocoding failure keeps the coordinates and shows an honest label',
        () async {
      final container = build(geocoder: _Geocoder(fails: true));
      container.listen(deliveryLocationViewProvider, (_, _) {});

      await container.read(deliveryLocationProvider.future);
      await container.read(deviceAddressProvider.future);

      final view = container.read(deliveryLocationViewProvider);
      expect(view.phase, DeliveryLocationPhase.ready);
      expect(view.addressFailed, isTrue);
      expect(view.primary, 'Current location');
      expect(view.location!.latitude, _bijnor.latitude);
      final coords = await container.read(discoveryCoordinatesProvider.future);
      expect(coords, _bijnor, reason: 'distance still works');
    });

    test('GPS failure is "unavailable": no coordinates, no 0,0', () async {
      final container = build(
        fix: null,
        gpsFailure: const LocationException(
          LocationFailure.permissionDenied,
          'Location permission is required to show restaurants near you.',
        ),
      );
      container.listen(deliveryLocationViewProvider, (_, _) {});

      final state = await container.read(deliveryLocationProvider.future);
      expect(state, isA<DeliveryLocationUnavailable>());
      expect(await container.read(discoveryCoordinatesProvider.future), isNull);
      final view = container.read(deliveryLocationViewProvider);
      expect(view.phase, DeliveryLocationPhase.unavailable);
      expect(view.primary, 'Select location');
    });

    test('a pinned saved Home never touches GPS or the geocoder', () async {
      final gps = _Gps(_bijnor);
      final geocoder = _Geocoder(address: _bijnorAddress);
      final container = build(
        addresses: const [_home],
        signedIn: true,
        gps: gps,
        geocoder: geocoder,
      );
      container.listen(deliveryLocationViewProvider, (_, _) {});

      await container.read(deliveryLocationProvider.future);
      final view = container.read(deliveryLocationViewProvider);
      expect(view.location!.label, 'Home');
      expect(
        await container.read(discoveryCoordinatesProvider.future),
        const UserLocation(latitude: 29.3724, longitude: 78.1358),
      );
      expect(gps.calls, 0, reason: 'no GPS permission request for a returning user');
      expect(geocoder.points, isEmpty);
    });

    test('switching Home -> current location moves discovery coordinates',
        () async {
      const phone = UserLocation(latitude: 28.5355, longitude: 77.3910);
      final container = build(
        addresses: const [_home],
        signedIn: true,
        fix: phone,
      );
      container.listen(discoveryCoordinatesProvider, (_, _) {});

      expect(
        await container.read(discoveryCoordinatesProvider.future),
        const UserLocation(latitude: 29.3724, longitude: 78.1358),
      );

      container.read(useCurrentLocationProvider.notifier).choose(true);
      expect(await container.read(discoveryCoordinatesProvider.future), phone);

      container.read(useCurrentLocationProvider.notifier).choose(false);
      expect(
        await container.read(discoveryCoordinatesProvider.future),
        const UserLocation(latitude: 29.3724, longitude: 78.1358),
      );
    });

    test('the device fix is requested once, not once per consumer', () async {
      final gps = _Gps(_bijnor);
      final container = build(gps: gps);
      await Future.wait([
        container.read(currentLocationProvider.future),
        container.read(discoveryCoordinatesProvider.future),
        container.read(deliveryLocationProvider.future),
      ]);
      await container.read(deviceAddressProvider.future);
      expect(gps.calls, 1);
    });

    test('an unpinned saved address needs confirmation and reads no GPS',
        () async {
      final gps = _Gps(_bijnor);
      final container = build(
        addresses: const [_unpinned],
        signedIn: true,
        gps: gps,
      );
      final state = await container.read(deliveryLocationProvider.future);
      expect(state, isA<DeliveryLocationNeedsConfirmation>());
      expect(await container.read(discoveryCoordinatesProvider.future), isNull);
      expect(gps.calls, 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('restaurant distances', () {
    const restaurants = {
      'restaurants': [
        {
          'id': 1,
          'name': 'Iconic',
          'distance_km': 1.8,
          'delivery_time_minutes': 20,
        },
        {
          'id': 2,
          'name': 'Khalsa Pizza',
          'distance': '4.2 km',
          'delivery_time_minutes': 25,
        },
        {'id': 3, 'name': 'No Coordinates'},
      ],
    };

    test('different restaurants get different distances; unknown is null',
        () async {
      final (repo, adapter) = _catalogServing(restaurants);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appControllerProvider.overrideWith(_SignedOut.new),
          catalogRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(_Gps(_bijnor)),
          reverseGeocoderProvider.overrideWithValue(
            _Geocoder(address: _bijnorAddress),
          ),
        ],
      );
      addTearDown(container.dispose);

      final list = await container.read(restaurantsProvider.future);

      expect(list[0].distanceKm, 1.8);
      expect(list[1].distanceKm, 4.2);
      expect(list[2].distanceKm, isNull, reason: 'never 0 for unknown');
      expect(formatDistanceKm(list[0].distanceKm), '1.8 km');
      expect(formatDistanceKm(list[1].distanceKm), '4.2 km');
      expect(formatDistanceKm(list[2].distanceKm), isNull);
      // The request carried the canonical (device) coordinates.
      final query = adapter.requests.single.queryParameters;
      expect(double.parse(query['lat']!), closeTo(_bijnor.latitude, 1e-9));
      expect(double.parse(query['lng']!), closeTo(_bijnor.longitude, 1e-9));
    });

    test('without any location the request carries none (no fake 0,0)',
        () async {
      final (repo, adapter) = _catalogServing(restaurants);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appControllerProvider.overrideWith(_SignedOut.new),
          catalogRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(
            _Gps(
              null,
              failure: const LocationException(
                LocationFailure.permissionDenied,
                'denied',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(restaurantsProvider.future);

      final query = adapter.requests.single.queryParameters;
      expect(query.containsKey('lat'), isFalse);
      expect(query.containsKey('lng'), isFalse);
    });

    test('a saved Home drives the list, not the phone GPS', () async {
      final (repo, adapter) = _catalogServing(restaurants);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appControllerProvider.overrideWith(_SignedIn.new),
          accountRepositoryProvider.overrideWithValue(_Account([_home])),
          catalogRepositoryProvider.overrideWithValue(repo),
          locationServiceProvider.overrideWithValue(
            _Gps(const UserLocation(latitude: 28.5, longitude: 77.3)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(restaurantsProvider.future);

      final query = adapter.requests.single.queryParameters;
      expect(double.parse(query['lat']!), closeTo(29.3724, 1e-9));
      expect(double.parse(query['lng']!), closeTo(78.1358, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  group('cart', () {
    late _Pricing pricing;
    late _Account account;

    Future<ProviderContainer> pumpCart(
      WidgetTester tester, {
      List<CustomerAddress> addresses = const [],
      UserLocation? fix = _bijnor,
      bool signedIn = true,
      bool geocodeFails = false,
    }) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      pricing = _Pricing();
      account = _Account(addresses);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appControllerProvider.overrideWith(
            signedIn ? _SignedIn.new : _SignedOut.new,
          ),
          accountRepositoryProvider.overrideWithValue(account),
          locationServiceProvider.overrideWithValue(
            _Gps(
              fix,
              failure: fix == null
                  ? const LocationException(
                      LocationFailure.unavailable,
                      'Could not determine your location.',
                    )
                  : null,
            ),
          ),
          reverseGeocoderProvider.overrideWithValue(
            _Geocoder(address: _bijnorAddress, fails: geocodeFails),
          ),
          validateCartUseCaseProvider.overrideWithValue(
            ValidateCartUseCase(pricing),
          ),
        ],
      );
      container
          .read(cartControllerProvider.notifier)
          .addItem(_item, restaurantId: '9');
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const CartScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets(
      'no saved address + valid GPS: priced, located, no contradiction',
      (tester) async {
        await pumpCart(tester);

        // Priced from the GPS pin.
        expect(pricing.calls.single, (_bijnor.latitude, _bijnor.longitude));
        // The address card describes where we are delivering, with the area.
        expect(find.text('Deliver to current location'), findsOneWidget);
        expect(find.text('Vijay Nagar, Bijnor, Uttar Pradesh'), findsOneWidget);
        // The two messages of the original bug never appear.
        expect(
          find.text('Confirm your address before placing the order'),
          findsNothing,
        );
        expect(
          find.text('This location is outside the current delivery area.'),
          findsNothing,
        );
        // The delivery fee is calculated and checkout is enabled.
        expect(find.text('₹95'), findsWidgets);
        // Door details are asked for - but only as a clear next step.
        expect(find.byKey(const Key('address-needs-door-details')), findsOne);
        expect(find.byKey(const Key('address-complete-details')), findsOne);
      },
    );

    testWidgets('no location at all: choose a location, no price, no ₹0', (
      tester,
    ) async {
      await pumpCart(tester, fix: null, signedIn: false);

      expect(pricing.calls, isEmpty, reason: 'nothing is priced without a pin');
      expect(find.text('Choose delivery location'), findsOneWidget);
      expect(
        find.text('This location is outside the current delivery area.'),
        findsNothing,
      );
      expect(find.byKey(const Key('pricing-choose-location')), findsOneWidget);
      expect(find.text('Delivery unavailable'), findsOneWidget);
    });

    testWidgets('a genuine outside-area answer is the only place it shows', (
      tester,
    ) async {
      final container = await pumpCart(tester);
      pricing.script = (_, _) => Result.failure(
        const DeliveryPricingFailure(DeliveryPricingStatus.noMatchingRule),
      );
      container.invalidate(cartBillProvider);
      await tester.pumpAndSettle();

      expect(
        find.text('This location is outside the current delivery area.'),
        findsWidgets,
      );
      expect(find.text('Delivery unavailable'), findsOneWidget);
    });

    testWidgets('a missing restaurant location is not blamed on the customer',
        (tester) async {
      final container = await pumpCart(tester);
      pricing.script = (_, _) => Result.failure(
        const DeliveryPricingFailure(
          DeliveryPricingStatus.missingRestaurantLocation,
        ),
      );
      container.invalidate(cartBillProvider);
      await tester.pumpAndSettle();

      expect(
        find.text('Delivery is temporarily unavailable for this restaurant.'),
        findsWidgets,
      );
      expect(
        find.text('This location is outside the current delivery area.'),
        findsNothing,
      );
    });

    testWidgets('retry re-prices from the CURRENT coordinates', (tester) async {
      final container = await pumpCart(tester, addresses: const [_home]);
      expect(pricing.calls.last, (29.3724, 78.1358));

      pricing.script = (_, _) => Result.failure(
        const DeliveryPricingFailure(DeliveryPricingStatus.pricingUnavailable),
      );
      container.invalidate(cartBillProvider);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pricing-retry')), findsOneWidget);

      // The customer moves to Work, then retries: the new pin is what is sent.
      account.addresses = [
        for (final a in [_home, _work])
          CustomerAddress(
            id: a.id,
            label: a.label,
            addressLine1: a.addressLine1,
            area: a.area,
            city: a.city,
            pincode: a.pincode,
            isDefault: a.id == 'work',
            latitude: a.latitude,
            longitude: a.longitude,
          ),
      ];
      pricing.script = null;
      await tester.tap(find.byKey(const Key('pricing-retry')));
      await tester.pumpAndSettle();

      expect(pricing.calls.last, (29.40, 78.20));
    });
  });

  // ---------------------------------------------------------------------------
  group('complete delivery address', () {
    testWidgets('keeps the exact coordinates and the geocoded area', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = _Account();
      CustomerAddress? result;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appControllerProvider.overrideWith(_SignedIn.new),
          accountRepositoryProvider.overrideWithValue(account),
          locationServiceProvider.overrideWithValue(_Gps(_bijnor)),
          reverseGeocoderProvider.overrideWithValue(
            _Geocoder(address: _bijnorAddress),
          ),
        ],
      );
      addTearDown(container.dispose);
      result = null;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            // Watching the view is what a mounted header does; it is also what
            // makes the device address resolve before the sheet opens.
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(deliveryLocationViewProvider);
                return Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async => result =
                          await showCompleteDeliveryAddressSheet(context),
                      child: const Text('open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Geography is shown, not asked for.
      expect(
        find.text('Vijay Nagar, Bijnor, Uttar Pradesh'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('complete-address-area')), findsNothing);
      expect(find.byKey(const Key('complete-address-pincode')), findsNothing);

      // House and receiver are required.
      await tester.tap(find.byKey(const Key('complete-address-save')));
      await tester.pump();
      expect(account.added, isEmpty);
      expect(
        find.text('Please enter your house, flat or street details.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('complete-address-house')),
        'House 42',
      );
      await tester.enterText(
        find.byKey(const Key('complete-address-receiver')),
        'Asha Rao',
      );
      await tester.tap(find.byKey(const Key('complete-address-save')));
      await tester.pumpAndSettle();

      final saved = account.added.single;
      expect(saved.addressLine1, 'House 42');
      expect(saved.receiverName, 'Asha Rao');
      expect(saved.label, 'Home');
      expect(saved.area, 'Vijay Nagar');
      expect(saved.city, 'Bijnor');
      expect(saved.state, 'Uttar Pradesh');
      expect(saved.pincode, '246722');
      expect(saved.isDefault, isTrue);
      // The pin is the one being priced - typing a house never relocates it.
      expect(saved.latitude, _bijnor.latitude);
      expect(saved.longitude, _bijnor.longitude);
      expect(result, isNotNull);
      expect(container.read(useCurrentLocationProvider), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('add address autofill', () {
    testWidgets('GPS pin fills area, city, state and pincode; house stays empty',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final geocoder = _Geocoder(address: _bijnorAddress);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith(_SignedIn.new),
            accountRepositoryProvider.overrideWithValue(_Account()),
            addressLocationCaptureProvider.overrideWithValue(
              _Capture(
                LocationCaptureResult.captured(
                  CapturedLocation(
                    latitude: _bijnor.latitude,
                    longitude: _bijnor.longitude,
                    accuracyMeters: 6,
                    capturedAt: DateTime(2026, 10, 15),
                  ),
                ),
              ),
            ),
            pincodeLookupProvider.overrideWithValue(_NoPincode()),
            locationServiceProvider.overrideWithValue(
              _Gps(
                null,
                failure: const LocationException(
                  LocationFailure.permissionDenied,
                  'denied',
                ),
              ),
            ),
            reverseGeocoderProvider.overrideWithValue(geocoder),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAddressFormSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      String text(String key) => tester
          .widget<TextFormField>(find.byKey(Key(key)))
          .controller!
          .text;

      expect(text('address-area'), isEmpty);
      final capture = find.byKey(const Key('address-use-location'));
      await tester.ensureVisible(capture);
      await tester.tap(capture);
      await tester.pumpAndSettle();

      expect(find.text('Location pinned'), findsOneWidget);
      expect(text('address-area'), 'Vijay Nagar');
      expect(text('address-city'), 'Bijnor');
      expect(text('address-state'), 'Uttar Pradesh');
      expect(text('address-pincode'), '246722');
      expect(text('address-house'), isEmpty, reason: 'only the customer knows');
      expect(geocoder.points.single, (_bijnor.latitude, _bijnor.longitude));
    });

    testWidgets('a value the customer typed is never overwritten', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith(_SignedIn.new),
            accountRepositoryProvider.overrideWithValue(_Account()),
            addressLocationCaptureProvider.overrideWithValue(
              _Capture(
                LocationCaptureResult.captured(
                  CapturedLocation(
                    latitude: _bijnor.latitude,
                    longitude: _bijnor.longitude,
                    accuracyMeters: 6,
                    capturedAt: DateTime(2026, 10, 15),
                  ),
                ),
              ),
            ),
            pincodeLookupProvider.overrideWithValue(_NoPincode()),
            locationServiceProvider.overrideWithValue(
              _Gps(
                null,
                failure: const LocationException(
                  LocationFailure.permissionDenied,
                  'denied',
                ),
              ),
            ),
            reverseGeocoderProvider.overrideWithValue(
              _Geocoder(address: _bijnorAddress),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAddressFormSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('address-area')),
        'My own area',
      );
      final capture = find.byKey(const Key('address-use-location'));
      await tester.ensureVisible(capture);
      await tester.tap(capture);
      await tester.pumpAndSettle();

      String text(String key) => tester
          .widget<TextFormField>(find.byKey(Key(key)))
          .controller!
          .text;
      expect(text('address-area'), 'My own area');
      expect(text('address-city'), 'Bijnor');
    });

    testWidgets('geocoder failure keeps the pin and says so', (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith(_SignedIn.new),
            accountRepositoryProvider.overrideWithValue(_Account()),
            addressLocationCaptureProvider.overrideWithValue(
              _Capture(
                LocationCaptureResult.captured(
                  CapturedLocation(
                    latitude: _bijnor.latitude,
                    longitude: _bijnor.longitude,
                    accuracyMeters: 6,
                    capturedAt: DateTime(2026, 10, 15),
                  ),
                ),
              ),
            ),
            pincodeLookupProvider.overrideWithValue(_NoPincode()),
            locationServiceProvider.overrideWithValue(
              _Gps(
                null,
                failure: const LocationException(
                  LocationFailure.permissionDenied,
                  'denied',
                ),
              ),
            ),
            reverseGeocoderProvider.overrideWithValue(_Geocoder(fails: true)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAddressFormSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final capture = find.byKey(const Key('address-use-location'));
      await tester.ensureVisible(capture);
      await tester.tap(capture);
      await tester.pumpAndSettle();

      expect(find.text('Location pinned'), findsOneWidget);
      expect(
        find.textContaining("couldn't fill in the area automatically"),
        findsOneWidget,
      );
    });
  });
}
