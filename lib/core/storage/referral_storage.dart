import 'package:shared_preferences/shared_preferences.dart';

/// Holds a referral code between opening a referral link and finishing signup.
///
/// A referral link is opened by someone with no account, and
/// `POST /referrals/customer_referral/apply` is authenticated, so the code
/// waits here until a session exists and is then applied once and discarded.
class ReferralStorage {
  static const _codeKey = 'pending_referral_code';
  static const _capturedAtKey = 'pending_referral_captured_at';

  /// A code followed months ago is not good evidence of who referred someone.
  /// The programme's own invite expiry is enforced server-side regardless.
  static const Duration ttl = Duration(days: 30);

  /// Customer codes only. A customer arriving with a rider (`MD`) or
  /// restaurant (`MR`) code must not be attributed to the wrong programme.
  static final RegExp _customerCodeShape = RegExp(r'^MG[A-Z0-9]{8}$');

  static String normalize(String? value) => (value ?? '').trim().toUpperCase();

  static bool isCustomerReferralCode(String? value) =>
      _customerCodeShape.hasMatch(normalize(value));

  /// The stored code, or null when there is none or it has expired.
  Future<String?> readPendingCode({DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_codeKey);
    if (code == null || code.isEmpty) return null;

    final capturedMs = preferences.getInt(_capturedAtKey);
    if (capturedMs != null) {
      final capturedAt = DateTime.fromMillisecondsSinceEpoch(capturedMs);
      if ((now ?? DateTime.now()).difference(capturedAt) >= ttl) {
        await clearPendingCode();
        return null;
      }
    }
    return code;
  }

  /// Stores [code] unless one is already held.
  ///
  /// The first referrer keeps the attribution, which is also what the server
  /// enforces: one attribution per account, first one wins. Silently swapping
  /// codes would raise an expectation the backend will refuse.
  Future<bool> storePendingCode(String code, {DateTime? now}) async {
    final normalized = normalize(code);
    if (!isCustomerReferralCode(normalized)) return false;
    if (await readPendingCode(now: now) != null) return false;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_codeKey, normalized);
    await preferences.setInt(
      _capturedAtKey,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
    return true;
  }

  Future<void> clearPendingCode() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_codeKey);
    await preferences.remove(_capturedAtKey);
  }
}
