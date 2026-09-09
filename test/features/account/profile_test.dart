import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turquoise_delivery/core/services/api_client.dart';
import 'package:turquoise_delivery/shared/repositories/account_repository.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(jsonEncode(body), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

AccountRepository repositoryServing(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _StubAdapter(body);
  return AccountRepository(ApiClient(restaurantDio: dio, userDio: dio));
}

void main() {
  // The exact envelope restaurant-service sends from
  // controller/customer_web_extended.go GetProfile: the identity lives under
  // `customer`, alongside `culinary_profile` and `stats`.
  test('GET /customer-web/profile is parsed from its `customer` envelope',
      () async {
    final repository = repositoryServing({
      'status': 'success',
      'message': 'customer profile',
      'data': {
        'customer': {
          'user_id': 'usr_91',
          'customer_id': 'usr_91',
          'name': 'Gursevak',
          'phone': '9876543210',
          'email': 'g@example.com',
          'avatar_url': '',
          'initials': 'G',
          'joined_at': '2025-01-04T00:00:00Z',
        },
        'culinary_profile': {'tags': <String>[], 'orders_count': 3},
        'stats': {'total_orders': 3},
      },
    });

    final profile = await repository.fetchProfile();

    expect(profile.name, 'Gursevak');
    expect(profile.phone, '9876543210');
    expect(profile.email, 'g@example.com');
    expect(profile.id, 'usr_91');
  });

  test('PATCH /customer-web/profile is parsed from the same envelope',
      () async {
    final repository = repositoryServing({
      'status': 'success',
      'message': 'profile updated',
      'data': {
        'customer': {
          'user_id': 'usr_91',
          'name': 'Gursevak Singh',
          'phone': '9876543210',
          'email': 'new@example.com',
        },
      },
    });

    final profile =
        await repository.updateProfile(name: 'Gursevak Singh', email: 'new@example.com');

    expect(profile.name, 'Gursevak Singh');
    expect(profile.email, 'new@example.com');
  });

  // Older/other handlers nest under `user`, and some return the object flat.
  // Both must keep working.
  test('a `user` envelope and a flat object both still parse', () async {
    final nested = await repositoryServing({
      'data': {
        'user': {'user_id': 'u1', 'name': 'Nested', 'phone': '1112223334'},
      },
    }).fetchProfile();
    expect(nested.name, 'Nested');

    final flat = await repositoryServing({
      'data': {'id': 'u2', 'full_name': 'Flat', 'mobile': '5556667778'},
    }).fetchProfile();
    expect(flat.name, 'Flat');
    expect(flat.phone, '5556667778');
  });
}
