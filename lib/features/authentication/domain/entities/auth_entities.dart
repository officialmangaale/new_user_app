/// Domain entities for the authentication feature.
///
/// These are pure value objects with no infrastructure dependencies. The
/// `fromJson` factories live in the data layer (DTOs), not here.
library;

/// An authenticated customer identity.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          userId == other.userId &&
          phone == other.phone;

  @override
  int get hashCode => Object.hash(userId, phone);

  @override
  String toString() => 'AuthUser($userId, $name)';
}

/// A verified session containing a bearer token and the user identity.
class AuthSession {
  const AuthSession({required this.authToken, required this.user});

  final String authToken;
  final AuthUser user;
}

/// Metadata returned after an OTP has been dispatched.
class OtpSendResult {
  const OtpSendResult({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  final String phone;
  final int expiresInSeconds;
  final int resendAfterSeconds;
}
