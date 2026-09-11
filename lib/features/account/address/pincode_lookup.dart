import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// A post office served by a PIN code.
class PostOffice {
  const PostOffice({
    required this.name,
    required this.block,
    required this.delivers,
  });

  final String name;

  /// Sub-district ("Block"); "NA" from the source is normalised to empty.
  final String block;

  /// Whether the post office delivers mail. Informational only.
  final bool delivers;
}

class PincodeDetails {
  const PincodeDetails({
    required this.pincode,
    required this.district,
    required this.state,
    required this.postOffices,
  });

  final String pincode;
  final String district;
  final String state;
  final List<PostOffice> postOffices;
}

enum PincodeLookupStatus { found, notFound, failed }

class PincodeLookupResult {
  const PincodeLookupResult._(this.status, [this.details]);

  const PincodeLookupResult.found(PincodeDetails details)
    : this._(PincodeLookupStatus.found, details);
  const PincodeLookupResult.notFound() : this._(PincodeLookupStatus.notFound);
  const PincodeLookupResult.failed() : this._(PincodeLookupStatus.failed);

  final PincodeLookupStatus status;
  final PincodeDetails? details;
}

/// Suggests district, state and post offices for a PIN code. A helper only:
/// the address form never depends on it, and a PIN code says nothing about
/// the exact address or its coordinates.
abstract class PincodeLookup {
  Future<PincodeLookupResult> lookup(String pincode);
}

/// Uses the free public India Post data served by api.postalpincode.in.
///
/// It has no published SLA or rate limit (evaluated 2026-09-11: HTTPS, about
/// 1.3–1.9 s per lookup, JSON). Its use is therefore bounded:
///  * a separate HTTP client with no interceptors, so the customer's login
///    token is never sent to a third party;
///  * a short timeout, and any failure becomes [PincodeLookupStatus.failed]
///    rather than an exception;
///  * results cached for the session, so re-typing a PIN code is free.
///
/// A backend proxy with a shared cache would remove the third-party
/// dependency from the app; see docs/new-user-address-flow.
class PostalPincodeLookup implements PincodeLookup {
  PostalPincodeLookup({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.postalpincode.in',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;
  final Map<String, PincodeLookupResult> _cache = {};

  @override
  Future<PincodeLookupResult> lookup(String pincode) async {
    final cached = _cache[pincode];
    if (cached != null) return cached;
    try {
      final response = await _dio.get<dynamic>('/pincode/$pincode');
      final result = parsePostalPincodeResponse(pincode, response.data);
      // Failures are not cached: the next attempt may succeed.
      if (result.status != PincodeLookupStatus.failed) {
        _cache[pincode] = result;
      }
      _log(
        result.status == PincodeLookupStatus.failed
            ? 'address_pincode_lookup_failed reason=unparseable'
            : 'address_pincode_lookup_success status=${result.status.name}',
      );
      return result;
    } on DioException catch (error) {
      _log('address_pincode_lookup_failed reason=${error.type.name}');
      return const PincodeLookupResult.failed();
    }
  }

  void _log(String event) {
    assert(() {
      debugPrint('[Address] $event');
      return true;
    }());
  }
}

/// Parses `[{"Status": "Success" | "Error", "PostOffice": [...] | null}]`.
PincodeLookupResult parsePostalPincodeResponse(String pincode, Object? body) {
  if (body is! List || body.isEmpty || body.first is! Map) {
    return const PincodeLookupResult.failed();
  }
  final envelope = Map<String, dynamic>.from(body.first as Map);
  final status = '${envelope['Status'] ?? ''}'.toLowerCase();
  final offices = envelope['PostOffice'];
  if (status == 'error' || offices == null) {
    return const PincodeLookupResult.notFound();
  }
  if (status != 'success' || offices is! List) {
    return const PincodeLookupResult.failed();
  }

  String clean(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.toUpperCase() == 'NA' ? '' : text;
  }

  final postOffices = <PostOffice>[];
  String district = '';
  String state = '';
  for (final raw in offices.whereType<Map>()) {
    final name = clean(raw['Name']);
    if (name.isEmpty) continue;
    district = district.isEmpty ? clean(raw['District']) : district;
    state = state.isEmpty ? clean(raw['State']) : state;
    postOffices.add(
      PostOffice(
        name: name,
        block: clean(raw['Block']),
        delivers: '${raw['DeliveryStatus'] ?? ''}'.toLowerCase() == 'delivery',
      ),
    );
  }
  if (postOffices.isEmpty) {
    return const PincodeLookupResult.notFound();
  }
  return PincodeLookupResult.found(
    PincodeDetails(
      pincode: pincode,
      district: district,
      state: state,
      postOffices: postOffices,
    ),
  );
}
