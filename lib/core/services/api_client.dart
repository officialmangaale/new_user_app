import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Reads the current bearer token, or null when the user is a guest.
typedef TokenReader = Future<String?> Function();

/// Called when the backend rejects a token, so the app can clear the session.
typedef UnauthorizedHandler = Future<void> Function();

/// HTTP entry point for both Mangaale customer services.
///
/// Conventions match the existing food-ordering web client
/// (`src/services/http.ts`): JSON in/out, `Authorization: Bearer <token>`,
/// a 15 s timeout, and failures normalized to [ApiException].
class ApiClient {
  ApiClient({
    Dio? restaurantDio,
    Dio? userDio,
    TokenReader? tokenReader,
    UnauthorizedHandler? onUnauthorized,
  }) : restaurant =
           restaurantDio ?? _build(AppConfig.restaurantServiceBaseUrl),
       user = userDio ?? _build(AppConfig.userServiceBaseUrl) {
    _attachInterceptors(restaurant, tokenReader, onUnauthorized);
    _attachInterceptors(user, tokenReader, onUnauthorized);
  }

  /// restaurant-service: catalog, cart, orders, tracking, notifications.
  final Dio restaurant;

  /// user-service: customer OTP auth, profile, addresses.
  final Dio user;

  /// Retained so existing callers that referenced `client.dio` keep compiling.
  Dio get dio => restaurant;

  static Dio _build(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Non-2xx is surfaced through DioException so every failure funnels
        // into ApiException.fromDioException.
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
  }

  static void _attachInterceptors(
    Dio dio,
    TokenReader? tokenReader,
    UnauthorizedHandler? onUnauthorized,
  ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Endpoints that accept an optional token still benefit from it, so
          // it is attached whenever one exists.
          if (tokenReader != null) {
            final token = await tokenReader();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && onUnauthorized != null) {
            await onUnauthorized();
          }
          handler.next(error);
        },
      ),
    );
  }
}

/// Unwraps the platform's `{ status, message, data }` envelope.
///
/// The backend is inconsistent about wrapping — some handlers return the
/// payload directly. The web client solves this with `unwrapApiResponse`
/// (`src/utils/apiAdapters.ts`); this is the Dart equivalent.
Object? unwrapApiResponse(Object? raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    if (map.containsKey('data')) {
      final data = map['data'];
      if (data != null) return data;
    }
  }
  return raw;
}

/// Convenience: unwrap into a JSON object.
Map<String, dynamic> unwrapApiObject(Object? raw) {
  final unwrapped = unwrapApiResponse(raw);
  if (unwrapped is Map) return Map<String, dynamic>.from(unwrapped);
  return <String, dynamic>{};
}

/// Convenience: unwrap into a JSON list.
List<Map<String, dynamic>> unwrapApiList(Object? raw, {String? key}) {
  final unwrapped = unwrapApiResponse(raw);
  if (unwrapped is List) {
    return unwrapped
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
  if (unwrapped is Map && key != null) {
    final nested = unwrapped[key];
    if (nested is List) {
      return nested
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }
  }
  return const <Map<String, dynamic>>[];
}
