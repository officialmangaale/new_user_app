import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which promotional push campaign the customer last opened, so the
/// order they place next can be attributed to it.
///
/// Last-touch with a short window: a newer campaign replaces an older one, and
/// the id expires after [ttl]. It is cleared once an order is placed, so a
/// campaign is credited with one order, not with everything the customer buys
/// afterwards. Attribution is best-effort by design: every failure here yields
/// "no campaign" and must never get in the way of placing an order.
class CampaignAttributionStorage {
  const CampaignAttributionStorage();

  static const _idKey = 'push_campaign_id';
  static const _atKey = 'push_campaign_opened_at';

  static const Duration ttl = Duration(hours: 24);

  Future<void> store(int campaignId, {DateTime? now}) async {
    if (campaignId <= 0) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_idKey, campaignId);
      await preferences.setInt(
        _atKey,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {
      // Attribution is optional.
    }
  }

  /// The campaign id opened within [ttl], or null.
  Future<int?> read({DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final id = preferences.getInt(_idKey);
      final openedMs = preferences.getInt(_atKey);
      if (id == null || openedMs == null) return null;
      final openedAt = DateTime.fromMillisecondsSinceEpoch(openedMs);
      if ((now ?? DateTime.now()).difference(openedAt) >= ttl) {
        await clear();
        return null;
      }
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_idKey);
      await preferences.remove(_atKey);
    } catch (_) {
      // Nothing to clean up if storage is unavailable.
    }
  }
}
