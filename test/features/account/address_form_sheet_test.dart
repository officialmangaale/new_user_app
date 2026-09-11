import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/features/account/address/address_form_logic.dart';
import 'package:turquoise_delivery/features/account/address/address_form_sheet.dart';
import 'package:turquoise_delivery/features/account/address/address_location_capture.dart';
import 'package:turquoise_delivery/features/account/address/address_providers.dart';
import 'package:turquoise_delivery/features/account/address/pincode_lookup.dart';
import 'package:turquoise_delivery/features/account/presentation/addresses_screen.dart';
import 'package:turquoise_delivery/features/orders/providers/orders_providers.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository();

  /// How a save behaves; defaults to echoing the payload back with an id.
  Future<CustomerAddress> Function(CustomerAddress payload)? onAdd;
  final List<CustomerAddress> added = [];
  final List<CustomerAddress> stored = [];
  int fetchCalls = 0;

  @override
  Future<CustomerAddress> addAddress(CustomerAddress address) {
    added.add(address);
    final handler =
        onAdd ??
        (payload) async {
          final saved = CustomerAddress(
            id: 'a${added.length}',
            label: payload.label,
            addressLine1: payload.addressLine1,
            area: payload.area,
            city: payload.city,
            pincode: payload.pincode,
            isDefault: payload.isDefault,
            latitude: payload.latitude,
            longitude: payload.longitude,
          );
          stored.add(saved);
          return saved;
        };
    return handler(address);
  }

  @override
  Future<List<CustomerAddress>> fetchAddresses() async {
    fetchCalls++;
    return List.of(stored);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakeLocationCapture implements AddressLocationCapture {
  _FakeLocationCapture(this.result);

  LocationCaptureResult result;
  int captures = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<LocationCaptureResult> capture() async {
    captures++;
    return result;
  }

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}

class _FakePincodeLookup implements PincodeLookup {
  _FakePincodeLookup();

  PincodeLookupResult result = const PincodeLookupResult.notFound();
  final List<String> looked = [];

  @override
  Future<PincodeLookupResult> lookup(String pincode) async {
    looked.add(pincode);
    return result;
  }
}

const _gurgaon = PincodeLookupResult.found(
  PincodeDetails(
    pincode: '122003',
    district: 'Gurgaon',
    state: 'Haryana',
    postOffices: [
      PostOffice(name: 'Gurgaon Sector 45', block: '', delivers: true),
      PostOffice(name: 'Jharsa', block: '', delivers: true),
    ],
  ),
);

void main() {
  late _FakeAccountRepository repository;
  late _FakeLocationCapture location;
  late _FakePincodeLookup pincode;
  late Future<CustomerAddress?> sheetResult;

  setUp(() {
    repository = _FakeAccountRepository();
    location = _FakeLocationCapture(
      const LocationCaptureResult.failed(
        LocationCaptureFailure.permissionDenied,
      ),
    );
    pincode = _FakePincodeLookup();
  });

  List<Override> overrides() => [
    accountRepositoryProvider.overrideWithValue(repository),
    addressLocationCaptureProvider.overrideWithValue(location),
    pincodeLookupProvider.overrideWithValue(pincode),
  ];

  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await useTallScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => sheetResult = showAddressFormSheet(context),
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

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  Future<void> fillValidAddress(
    WidgetTester tester, {
    String pin = '560038',
  }) async {
    await enter(tester, 'address-house', '108');
    await enter(tester, 'address-area', 'Sector 49');
    await enter(tester, 'address-pincode', pin);
    // Past the pincode debounce.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.byKey(const Key('address-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
  }

  group('validation', () {
    testWidgets('an empty form shows what is missing and sends nothing', (
      tester,
    ) async {
      await openSheet(tester);

      await tapSave(tester);

      expect(find.text(AddressCopy.houseRequired), findsOneWidget);
      expect(find.text(AddressCopy.areaRequired), findsOneWidget);
      expect(find.text(AddressCopy.pincodeInvalid), findsOneWidget);
      expect(repository.added, isEmpty);
    });

    testWidgets('a short pincode is rejected', (tester) async {
      await openSheet(tester);
      await fillValidAddress(tester, pin: '12200');

      await tapSave(tester);

      expect(find.text(AddressCopy.pincodeInvalid), findsOneWidget);
      expect(repository.added, isEmpty);
    });

    testWidgets('"Other" needs a label', (tester) async {
      await openSheet(tester);
      await fillValidAddress(tester);
      await tester.tap(find.byKey(const Key('address-label-Other')));
      await tester.pump();

      await tapSave(tester);

      expect(find.text(AddressCopy.labelRequired), findsOneWidget);
      expect(repository.added, isEmpty);
    });
  });

  group('saving', () {
    testWidgets('shows Saving… and ignores a second tap', (tester) async {
      final pending = Completer<CustomerAddress>();
      repository.onAdd = (_) => pending.future;
      await openSheet(tester);
      await fillValidAddress(tester);

      final save = find.byKey(const Key('address-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();

      expect(find.text('Saving…'), findsOneWidget);
      expect(repository.added, hasLength(1), reason: 'no duplicate submission');
      expect(
        tester.widget<FilledButton>(save).onPressed,
        isNull,
        reason: 'disabled while saving',
      );

      pending.complete(
        const CustomerAddress(
          id: 'a1',
          label: 'Home',
          addressLine1: '108',
          area: 'Sector 49',
          city: '',
          pincode: '560038',
          isDefault: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(AddressFormSheet),
        findsNothing,
        reason: 'sheet closes',
      );
      expect((await sheetResult)?.id, 'a1');
    });

    testWidgets('a manual address saves without any location', (tester) async {
      await openSheet(tester);
      await fillValidAddress(tester);

      await tapSave(tester);
      await tester.pumpAndSettle();

      final sent = repository.added.single;
      expect(sent.addressLine1, '108');
      expect(sent.area, 'Sector 49');
      expect(sent.pincode, '560038');
      expect(sent.label, 'Home');
      expect(
        sent.isDefault,
        isTrue,
        reason: 'Deliver my orders here is on by default',
      );
      expect(sent.hasPin, isFalse);
      expect(
        location.captures,
        0,
        reason: 'GPS is never used unless asked for',
      );
    });

    testWidgets('a server field error appears on that field', (tester) async {
      repository.onAdd = (_) async => throw const ApiException(
        statusCode: 400,
        message: 'valid pincode is required',
        errors: {'pincode': 'valid pincode is required'},
      );
      await openSheet(tester);
      await fillValidAddress(tester);

      await tapSave(tester);
      await tester.pump();

      expect(find.text(AddressCopy.pincodeInvalid), findsOneWidget);
      expect(
        find.byType(AddressFormSheet),
        findsOneWidget,
        reason: 'stays open',
      );
    });

    testWidgets(
      'a network error is shown in the sheet and save can be retried',
      (tester) async {
        repository.onAdd = (_) async => throw const ApiException(
          statusCode: 0,
          message: 'Network error. Please check your connection and try again.',
        );
        await openSheet(tester);
        await fillValidAddress(tester);

        await tapSave(tester);
        await tester.pump();

        expect(find.byKey(const Key('address-save-error')), findsOneWidget);
        expect(find.text(AddressCopy.saveOffline), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('address-save')))
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('a save that never answers times out with a message', (
      tester,
    ) async {
      repository.onAdd = (_) => Completer<CustomerAddress>().future;
      await openSheet(tester);
      await fillValidAddress(tester);

      await tapSave(tester);
      await tester.pump(const Duration(seconds: 26));

      expect(find.text(AddressCopy.saveTimeout), findsOneWidget);
    });

    testWidgets('an expired session asks to log in again', (tester) async {
      repository.onAdd = (_) async =>
          throw const ApiException(statusCode: 401, message: 'unauthenticated');
      await openSheet(tester);
      await fillValidAddress(tester);

      await tapSave(tester);
      await tester.pump();

      expect(find.text(AddressCopy.authExpired), findsOneWidget);
    });
  });

  group('current location', () {
    testWidgets('permission denied is explained and manual save still works', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('address-use-location')));
      await tester.pump();

      expect(find.text(AddressCopy.locationDenied), findsOneWidget);

      await fillValidAddress(tester);
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.added.single.hasPin, isFalse);
    });

    testWidgets('GPS off offers the location settings', (tester) async {
      location.result = const LocationCaptureResult.failed(
        LocationCaptureFailure.serviceDisabled,
      );
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('address-use-location')));
      await tester.pump();

      expect(find.text(AddressCopy.gpsOff), findsOneWidget);
      await tester.tap(find.text('Turn on location'));
      expect(location.locationSettingsOpened, 1);
    });

    testWidgets('a captured pin is saved with the address', (tester) async {
      location.result = LocationCaptureResult.captured(
        CapturedLocation(
          latitude: 28.4089,
          longitude: 77.0532,
          accuracyMeters: 25,
          capturedAt: DateTime(2026, 9, 11),
        ),
      );
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('address-use-location')));
      await tester.pump();
      expect(find.text('Location pinned'), findsOneWidget);

      await fillValidAddress(tester);
      await tapSave(tester);
      await tester.pumpAndSettle();

      final sent = repository.added.single;
      expect(sent.latitude, 28.4089);
      expect(sent.longitude, 77.0532);
      expect(sent.locationAccuracyMeters, 25);
    });
  });

  group('pincode lookup', () {
    testWidgets('fills city and state and offers post offices', (tester) async {
      pincode.result = _gurgaon;
      await openSheet(tester);
      await enter(tester, 'address-house', '108');

      await enter(tester, 'address-pincode', '122003');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(pincode.looked, ['122003']);
      expect(find.text('Gurgaon, Haryana'), findsOneWidget);
      expect(find.text('Select your post office (optional)'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-city')))
            .controller
            ?.text,
        'Gurgaon',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-state')))
            .controller
            ?.text,
        'Haryana',
      );

      final office = find.text('Jharsa');
      await tester.ensureVisible(office);
      await tester.tap(office);
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-area')))
            .controller
            ?.text,
        'Jharsa',
        reason: 'an empty area takes the post office as a suggestion',
      );

      await tapSave(tester);
      await tester.pumpAndSettle();
      final sent = repository.added.single;
      expect(sent.city, 'Gurgaon');
      expect(sent.state, 'Haryana');
      expect(sent.district, 'Gurgaon');
    });

    testWidgets('waits for all six digits', (tester) async {
      await openSheet(tester);

      await enter(tester, 'address-pincode', '12200');
      await tester.pump(const Duration(milliseconds: 500));

      expect(pincode.looked, isEmpty);
    });

    testWidgets('a failed lookup never blocks saving', (tester) async {
      pincode.result = const PincodeLookupResult.failed();
      await openSheet(tester);
      await fillValidAddress(tester, pin: '122003');

      expect(find.text(AddressCopy.pincodeLookupFailed), findsOneWidget);

      await tapSave(tester);
      await tester.pumpAndSettle();
      expect(repository.added, hasLength(1));
    });
  });

  group('saved addresses screen', () {
    // The original bug: the save failed silently. Now a save closes the sheet,
    // refreshes the list, and confirms on the page where it can be seen.
    testWidgets('a new address appears after saving', (tester) async {
      await useTallScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(home: AddressesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No saved addresses'), findsOneWidget);
      final fetchesBefore = repository.fetchCalls;

      await tester.tap(find.text('Add address'));
      await tester.pumpAndSettle();
      await fillValidAddress(tester);
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AddressFormSheet), findsNothing);
      expect(find.text('Address saved. Delivering here.'), findsOneWidget);
      expect(repository.fetchCalls, greaterThan(fetchesBefore));
      expect(find.text('Delivering here'), findsOneWidget);
      expect(find.textContaining('108'), findsOneWidget);
    });
  });
}
