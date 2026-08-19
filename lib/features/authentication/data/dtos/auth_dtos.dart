/// Data-transfer objects for the authentication API.
///
/// DTOs own the `fromJson` factories — the domain entities stay clean.
/// Each DTO has a `toEntity()` method that produces the domain type.
library;

import '../../domain/entities/auth_entities.dart';

/// DTO for `POST /customers/auth/send-otp` response.
class OtpSendResultDto {
  const OtpSendResultDto({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  final String phone;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  factory OtpSendResultDto.fromJson(Map<String, dynamic> json) {
    return OtpSendResultDto(
      phone: (json['phone'] as String?) ?? '',
      expiresInSeconds: _asInt(json['expires_in_seconds']),
      resendAfterSeconds: _asInt(json['resend_after_seconds']),
    );
  }

  OtpSendResult toEntity() => OtpSendResult(
    phone: phone,
    expiresInSeconds: expiresInSeconds,
    resendAfterSeconds: resendAfterSeconds,
  );
}

/// DTO for the `user` object inside a login response.
class AuthUserDto {
  const AuthUserDto({
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

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    return AuthUserDto(
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      isNewUser: json['is_new_user'] == true,
    );
  }

  AuthUser toEntity() => AuthUser(
    userId: userId,
    name: name,
    phone: phone,
    email: email,
    role: role,
    isNewUser: isNewUser,
  );
}

/// DTO for `POST /customers/auth/verify-otp` response.
class AuthSessionDto {
  const AuthSessionDto({required this.authToken, required this.user});

  final String authToken;
  final AuthUserDto user;

  factory AuthSessionDto.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return AuthSessionDto(
      authToken: (json['authToken'] as String?) ?? '',
      user: AuthUserDto.fromJson(
        rawUser is Map
            ? Map<String, dynamic>.from(rawUser)
            : <String, dynamic>{},
      ),
    );
  }

  AuthSession toEntity() => AuthSession(
    authToken: authToken,
    user: user.toEntity(),
  );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
