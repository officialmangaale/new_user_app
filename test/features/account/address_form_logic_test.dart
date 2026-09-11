import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_exception.dart';
import 'package:turquoise_delivery/features/account/address/address_form_logic.dart';
import 'package:turquoise_delivery/features/account/address/pincode_lookup.dart';

void main() {
  group('field validation', () {
    test('required fields use the agreed copy', () {
      expect(validateLabel('  '), AddressCopy.labelRequired);
      expect(validateHouse(''), AddressCopy.houseRequired);
      expect(validateArea(' '), AddressCopy.areaRequired);
      expect(validateHouse('108'), isNull);
    });

    test('pincode must be six digits and not start with 0', () {
      for (final bad in [
        '',
        '12200',
        '1220033',
        '12200A',
        '012345',
        '12 003',
      ]) {
        expect(validatePincode(bad), AddressCopy.pincodeInvalid, reason: bad);
      }
      expect(validatePincode('122003'), isNull);
      expect(validatePincode(' 560038 '), isNull);
    });
  });

  test('house and street become one address line', () {
    expect(
      composeAddressLine1(house: '108', street: 'Sector 49'),
      '108, Sector 49',
    );
    expect(composeAddressLine1(house: '108', street: ' '), '108');
  });

  test('a pin is sent only as a valid pair', () {
    expect(isValidCoordinate(28.4089, 77.0532), isTrue);
    expect(isValidCoordinate(null, 77.0), isFalse);
    expect(isValidCoordinate(91, 77.0), isFalse);
    expect(isValidCoordinate(28, -181), isFalse);
    expect(isValidCoordinate(0, 0), isFalse, reason: 'a device with no fix');
  });

  group('describeSaveError', () {
    test('a timeout says so', () {
      expect(
        describeSaveError(TimeoutException('slow')).message,
        AddressCopy.saveTimeout,
      );
      expect(
        describeSaveError(
          const ApiException(
            statusCode: 0,
            message: 'Request timed out. Please check your connection.',
          ),
        ).message,
        AddressCopy.saveTimeout,
      );
    });

    test('no connection says so', () {
      expect(
        describeSaveError(
          const ApiException(
            statusCode: 0,
            message:
                'Network error. Please check your connection and try again.',
          ),
        ).message,
        AddressCopy.saveOffline,
      );
    });

    test('an expired session asks the customer to log in again', () {
      expect(
        describeSaveError(
          const ApiException(statusCode: 401, message: 'x'),
        ).message,
        AddressCopy.authExpired,
      );
    });

    test('a server field error lands on that field', () {
      final pincode = describeSaveError(
        const ApiException(
          statusCode: 400,
          message: 'valid pincode is required',
          errors: {'pincode': 'valid pincode is required'},
        ),
      );
      expect(pincode.field, AddressField.pincode);
      expect(pincode.message, AddressCopy.pincodeInvalid);

      final house = describeSaveError(
        const ApiException(
          statusCode: 400,
          message: 'address_line1 is required',
        ),
      );
      expect(house.field, AddressField.house);

      final pin = describeSaveError(
        const ApiException(
          statusCode: 400,
          message: 'latitude and longitude must be sent together',
          errors: {'latitude': 'latitude and longitude must be sent together'},
        ),
      );
      expect(pin.field, AddressField.location);
    });

    test('any other validation message from the server is shown', () {
      final error = describeSaveError(
        const ApiException(
          statusCode: 400,
          message: 'valid phone number is required',
        ),
      );
      expect(error.field, AddressField.general);
      expect(error.message, 'valid phone number is required');
    });

    // The old silent failure: anything that was not an ApiException escaped.
    test('an unexpected error still produces a message', () {
      expect(
        describeSaveError(StateError('boom')).message,
        AddressCopy.saveFailed,
      );
      expect(
        describeSaveError(
          const ApiException(statusCode: 500, message: 'db down'),
        ).message,
        AddressCopy.saveFailed,
      );
    });
  });

  group('planPincodeAutofill', () {
    test('fills empty city and state', () {
      final plan = planPincodeAutofill(
        currentCity: '',
        currentState: '',
        lastAutoCity: null,
        lastAutoState: null,
        suggestedCity: 'Gurgaon',
        suggestedState: 'Haryana',
      );
      expect(plan.city, 'Gurgaon');
      expect(plan.state, 'Haryana');
    });

    test('never overwrites what the customer typed', () {
      final plan = planPincodeAutofill(
        currentCity: 'Gurugram',
        currentState: '',
        lastAutoCity: null,
        lastAutoState: null,
        suggestedCity: 'Gurgaon',
        suggestedState: 'Haryana',
      );
      expect(plan.city, isNull);
      expect(plan.state, 'Haryana');
    });

    test('replaces its own earlier suggestion when the pincode changes', () {
      final plan = planPincodeAutofill(
        currentCity: 'Gurgaon',
        currentState: 'Haryana',
        lastAutoCity: 'Gurgaon',
        lastAutoState: 'Haryana',
        suggestedCity: 'Central Delhi',
        suggestedState: 'Delhi',
      );
      expect(plan.city, 'Central Delhi');
      expect(plan.state, 'Delhi');
    });
  });

  group('parsePostalPincodeResponse', () {
    test('reads district, state and post offices', () {
      final result = parsePostalPincodeResponse('122003', [
        {
          'Status': 'Success',
          'PostOffice': [
            {
              'Name': 'Gurgaon Sector 45',
              'Block': 'Sector -45',
              'District': 'Gurgaon',
              'State': 'Haryana',
              'DeliveryStatus': 'Delivery',
            },
            {
              'Name': 'Jharsa',
              'Block': 'NA',
              'District': 'Gurgaon',
              'State': 'Haryana',
              'DeliveryStatus': 'Delivery',
            },
          ],
        },
      ]);
      expect(result.status, PincodeLookupStatus.found);
      expect(result.details!.district, 'Gurgaon');
      expect(result.details!.state, 'Haryana');
      expect(result.details!.postOffices.map((p) => p.name), [
        'Gurgaon Sector 45',
        'Jharsa',
      ]);
      expect(
        result.details!.postOffices.last.block,
        '',
        reason: '"NA" is not a block',
      );
    });

    test('an unknown pincode is "not found", not a failure', () {
      final result = parsePostalPincodeResponse('999999', [
        {'Status': 'Error', 'Message': 'No records found', 'PostOffice': null},
      ]);
      expect(result.status, PincodeLookupStatus.notFound);
    });

    test('an unexpected shape is a failure, not a crash', () {
      expect(
        parsePostalPincodeResponse('1', 'oops').status,
        PincodeLookupStatus.failed,
      );
      expect(
        parsePostalPincodeResponse('1', const []).status,
        PincodeLookupStatus.failed,
      );
    });
  });
}
