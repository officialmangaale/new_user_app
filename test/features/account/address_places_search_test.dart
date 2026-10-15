import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/maps/map_capabilities.dart';
import 'package:turquoise_delivery/features/account/address/address_form_sheet.dart';
import 'package:turquoise_delivery/features/account/address/address_location_capture.dart';
import 'package:turquoise_delivery/features/account/address/address_providers.dart';
import 'package:turquoise_delivery/features/account/address/pincode_lookup.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

class _SearchCall {
  _SearchCall(this.query, this.token);
  final String query;
  final String token;
}

class _FakePlacesRepository implements AccountRepository {
  final List<_SearchCall> searches = [];
  final List<String> detailTokens = [];
  int reverseCalls = 0;
  bool failSearch = false;

  @override
  Future<List<AddressPlaceSuggestion>> searchAddressPlaces({
    required String query,
    required String sessionToken,
    double? latitude,
    double? longitude,
  }) async {
    searches.add(_SearchCall(query, sessionToken));
    if (failSearch) throw StateError('offline');
    return [
      AddressPlaceSuggestion(
        placeId: 'place-${searches.length}',
        primaryText: 'Sector 17',
        secondaryText: 'Chandigarh',
        fullText: 'Sector 17, Chandigarh',
      ),
    ];
  }

  @override
  Future<ResolvedCustomerLocation> resolveAddressPlace({
    required String placeId,
    required String sessionToken,
  }) async {
    detailTokens.add(sessionToken);
    // No coordinates: the form is filled without opening the map picker.
    return const ResolvedCustomerLocation(
      addressLine1: 'Sector 17',
      city: 'Chandigarh',
      state: 'Chandigarh',
      pincode: '160017',
      formattedAddress: 'Sector 17, Chandigarh, 160017, India',
    );
  }

  @override
  Future<ResolvedCustomerLocation> reverseGeocodeAddress({
    required double latitude,
    required double longitude,
  }) async {
    reverseCalls++;
    return const ResolvedCustomerLocation();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _NoPincodeLookup implements PincodeLookup {
  @override
  Future<PincodeLookupResult> lookup(String pincode) async =>
      const PincodeLookupResult.notFound();
}

class _NoLocation implements AddressLocationCapture {
  @override
  Future<LocationCaptureResult> capture() async =>
      const LocationCaptureResult.failed(LocationCaptureFailure.unavailable);
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  late _FakePlacesRepository repository;

  setUp(() => repository = _FakePlacesRepository());

  List<Override> overrides({required bool placesAvailable}) => [
    accountRepositoryProvider.overrideWithValue(repository),
    addressLocationCaptureProvider.overrideWithValue(_NoLocation()),
    pincodeLookupProvider.overrideWithValue(_NoPincodeLookup()),
    customerPlacesAvailableProvider.overrideWithValue(placesAvailable),
  ];

  Future<void> openSheet(
    WidgetTester tester, {
    bool placesAvailable = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(placesAvailable: placesAvailable),
        child: MaterialApp(
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
  }

  Future<void> type(WidgetTester tester, String text) async {
    final field = find.byKey(const Key('address-place-search'));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  const debounce = Duration(milliseconds: 500);

  testWidgets('no Places request is made until the customer types and pauses', (
    tester,
  ) async {
    await openSheet(tester);
    expect(repository.searches, isEmpty, reason: 'opening the form is free');

    await type(tester, 'Sec');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.searches, isEmpty, reason: 'still inside the debounce');
    await tester.pump(debounce);
    expect(repository.searches, hasLength(1));
    expect(repository.searches.single.query, 'Sec');
  });

  testWidgets('keystrokes inside the debounce window collapse into one request', (
    tester,
  ) async {
    await openSheet(tester);
    for (final text in ['Sec', 'Sect', 'Secto', 'Sector']) {
      await type(tester, text);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(debounce);
    expect(repository.searches, hasLength(1));
    expect(repository.searches.single.query, 'Sector');
  });

  testWidgets('fewer than three characters never reach the backend', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Se');
    await tester.pump(debounce * 2);
    expect(repository.searches, isEmpty);
  });

  testWidgets('re-entering the answered text does not request again', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Sector 17');
    await tester.pump(debounce);
    expect(repository.searches, hasLength(1));

    await type(tester, 'Sector 17 ');
    await tester.pump(debounce * 2);
    await type(tester, 'sector  17');
    await tester.pump(debounce * 2);
    expect(repository.searches, hasLength(1));
  });

  testWidgets('one session token spans the search and the details call', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'Sec');
    await tester.pump(debounce);
    await type(tester, 'Sector 1');
    await tester.pump(debounce);
    expect(repository.searches, hasLength(2));
    final token = repository.searches.first.token;
    expect(repository.searches.last.token, token);

    await tester.tap(find.text('Sector 17').first);
    await tester.pumpAndSettle();
    expect(repository.detailTokens, [token]);

    // After a place is resolved the next search is a new billing session.
    await type(tester, 'Sector 22');
    await tester.pump(debounce);
    expect(repository.searches, hasLength(3));
    expect(repository.searches.last.token, isNot(token));
  });

  testWidgets('a failed search is retried when the text changes, not cached', (
    tester,
  ) async {
    repository.failSearch = true;
    await openSheet(tester);
    await type(tester, 'Sector 17');
    await tester.pump(debounce);
    await tester.pump();
    expect(find.textContaining('Search is unavailable'), findsOneWidget);
    expect(repository.searches, hasLength(1));

    repository.failSearch = false;
    await type(tester, 'Sector 17 ');
    await tester.pump(debounce);
    // Same normalized text, but the first attempt failed: it is sent again.
    expect(repository.searches, hasLength(2));
  });

  testWidgets('the search box is absent when Places is not available', (
    tester,
  ) async {
    await openSheet(tester, placesAvailable: false);
    expect(find.byKey(const Key('address-place-search')), findsNothing);
    expect(repository.searches, isEmpty);
  });

  testWidgets('reverse geocoding stays off unless explicitly enabled', (
    tester,
  ) async {
    await openSheet(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AddressFormSheet)),
    );
    expect(container.read(customerReverseGeocodingAvailableProvider), isFalse);
    expect(repository.reverseCalls, 0);
  });
}
