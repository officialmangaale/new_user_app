import 'package:shared_preferences/shared_preferences.dart';

/// Persists the customer session issued by user-service.
///
/// Follows the same SharedPreferences pattern as [GuestStorage] so the app
/// keeps one storage approach. See the note in `docs/new-user-app` about
/// moving the token to `flutter_secure_storage` — that needs a new dependency
/// and is deliberately not done here.
class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _userNameKey = 'auth_user_name';
  static const _userPhoneKey = 'auth_user_phone';

  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    return (token == null || token.isEmpty) ? null : token;
  }

  /// `userId` is a string: user-service returns `user_id` as a string in
  /// `CustomerAuthUser`, not a number.
  Future<void> saveSession({
    required String token,
    String? userId,
    String? name,
    String? phone,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
    if (userId != null) await preferences.setString(_userIdKey, userId);
    if (name != null) await preferences.setString(_userNameKey, name);
    if (phone != null) await preferences.setString(_userPhoneKey, phone);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_userIdKey);
    await preferences.remove(_userNameKey);
    await preferences.remove(_userPhoneKey);
  }

  Future<String?> readUserId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_userIdKey);
  }

  Future<String?> readUserName() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_userNameKey);
  }

  Future<String?> readUserPhone() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_userPhoneKey);
  }
}
