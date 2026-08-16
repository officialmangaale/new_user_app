import 'package:dio/dio.dart';

import '../../core/services/api_client.dart';
import '../../core/services/api_exception.dart';

/// Result of `POST /customers/auth/send-otp`.
///
/// Field names match `CustomerOTPSendResult` in user-service
/// (`service/customer_service.go`).
class OtpSendResult {
  const OtpSendResult({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  final String phone;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    return OtpSendResult(
      phone: (json['phone'] as String?) ?? '',
      expiresInSeconds: _asInt(json['expires_in_seconds']),
      resendAfterSeconds: _asInt(json['resend_after_seconds']),
    );
  }
}

/// Authenticated customer, matching `CustomerAuthUser` in user-service.
///
/// `user_id` is a string on the wire — do not parse it as a number.
class AuthUser {
  const AuthUser({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.isNewUser,
  });

  final String userId;
  final String name;
  final String phone;
  final String email;
  final String role;
  final bool isNewUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      isNewUser: json['is_new_user'] == true,
    );
  }
}

/// Result of `POST /customers/auth/verify-otp` (`CustomerLoginResponse`).
class AuthSession {
  const AuthSession({required this.authToken, required this.user});

  final String authToken;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return AuthSession(
      authToken: (json['authToken'] as String?) ?? '',
      user: AuthUser.fromJson(
        rawUser is Map
            ? Map<String, dynamic>.from(rawUser)
            : <String, dynamic>{},
      ),
    );
  }
}

/// Customer OTP authentication against user-service.
///
/// These are the same two endpoints the production food-ordering web client
/// uses (`src/services/authApi.ts`); nothing new was added to the backend.
class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  static const String sendOtpPath = '/customers/auth/send-otp';
  static const String verifyOtpPath = '/customers/auth/verify-otp';

  Future<OtpSendResult> sendOtp(String phone) async {
    try {
      final response = await _client.user.post<dynamic>(
        sendOtpPath,
        data: <String, dynamic>{'phone': phone},
      );
      return OtpSendResult.fromJson(unwrapApiObject(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await _client.user.post<dynamic>(
        verifyOtpPath,
        data: <String, dynamic>{'phone': phone, 'otp': otp},
      );
      final session = AuthSession.fromJson(unwrapApiObject(response.data));
      if (session.authToken.isEmpty) {
        throw const ApiException(
          statusCode: 0,
          message: 'Login failed: the server did not return a session token.',
        );
      }
      return session;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
