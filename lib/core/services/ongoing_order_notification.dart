import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// What the customer should see in the notification shade for one order.
@immutable
class LiveOrderNotice {
  const LiveOrderNotice({
    required this.orderId,
    required this.title,
    required this.body,
    required this.grocery,
  });

  final String orderId;
  final String title;
  final String body;
  final bool grocery;

  /// Statuses after which an order has nothing left to track.
  static const terminalStatuses = {
    'delivered',
    'completed',
    'cancelled',
    'canceled',
    'rejected',
    'declined',
    'done',
  };

  static final _idPattern = RegExp(r'^[0-9]{1,19}$');

  /// A short customer-facing line for a backend status.
  static String labelFor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
      case 'placed':
      case 'new':
        return 'Order placed, waiting for the restaurant';
      case 'confirmed':
      case 'accepted':
        return 'Order confirmed';
      case 'preparing':
        return 'Being prepared';
      case 'ready':
        return 'Ready for pickup';
      case 'rider_assigned':
        return 'Delivery partner assigned';
      case 'picked_up':
      case 'out_for_delivery':
      case 'on_the_way':
        return 'On the way to you';
      default:
        return 'Order in progress';
    }
  }

  /// Reads an order-status push `data` payload. Returns null for anything that
  /// is not a customer order update with a numeric order id, so unrelated
  /// pushes (promotions, rider or restaurant alerts) never create one.
  static LiveOrderNotice? fromPushData(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}'.toLowerCase();
    final recipient = '${data['recipient_type'] ?? 'customer'}'.toLowerCase();
    if (recipient != 'customer') return null;
    const kinds = {'order_status_updated', 'order_status', 'order_update'};
    if (!kinds.contains(type)) return null;
    final id = '${data['orderId'] ?? data['order_id'] ?? ''}'.trim();
    if (!_idPattern.hasMatch(id)) return null;
    final status = '${data['status'] ?? ''}'.trim().toLowerCase();
    if (terminalStatuses.contains(status)) return null;
    final grocery = '${data['order_type'] ?? ''}'.toLowerCase() == 'grocery';
    final title = '${data['title'] ?? ''}'.trim();
    return LiveOrderNotice(
      orderId: id,
      title: 'Order #$id',
      body: status.isEmpty
          ? (title.isEmpty ? 'Order in progress' : title)
          : labelFor(status),
      grocery: grocery,
    );
  }

  /// The order id a push says has finished, or null.
  static String? finishedOrderId(Map<String, dynamic> data) {
    final id = '${data['orderId'] ?? data['order_id'] ?? ''}'.trim();
    if (!_idPattern.hasMatch(id)) return null;
    final status = '${data['status'] ?? ''}'.trim().toLowerCase();
    return terminalStatuses.contains(status) ? id : null;
  }
}

/// A persistent, quiet notification per active order, so the order stays
/// visible in the shade and on the lock screen while the app is minimised.
///
/// It is updated whenever the app learns a new status: from a status push
/// (foreground or background handler) and from the live-order refresh in the
/// app. It does not poll in the background; between pushes it shows the last
/// known status.
class OngoingOrderNotification {
  OngoingOrderNotification._();

  static const channelId = 'live_order_tracking';
  static const _channelName = 'Live order tracking';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _channelReady = false;

  /// Stable per order so an update replaces the previous one.
  @visibleForTesting
  static int notificationIdFor(String orderId) =>
      0x4c4f0000 | (int.tryParse(orderId) ?? orderId.hashCode) & 0xFFFF;

  /// Used from the background isolate, where nothing has initialised the
  /// plugin. In the app isolate PushNotificationService already has, and its
  /// tap callback must not be replaced.
  static Future<void> initializeForBackground() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    } catch (error) {
      log('Background notification init failed: $error');
    }
  }

  static Future<void> _ensureChannel() async {
    if (_channelReady) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            _channelName,
            description: 'Shows your active order until it is delivered.',
            importance: Importance.low,
            showBadge: false,
          ),
        );
    _channelReady = true;
  }

  static Future<void> show(LiveOrderNotice notice) async {
    try {
      await _ensureChannel();
      await _plugin.show(
        notificationIdFor(notice.orderId),
        notice.title,
        notice.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: 'Shows your active order until it is delivered.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            category: AndroidNotificationCategory.status,
            visibility: NotificationVisibility.public,
          ),
        ),
        // Same shape the tap handler already routes: opens the order's
        // tracking screen.
        payload: jsonEncode({
          'type': 'order_status_updated',
          'recipient_type': 'customer',
          'order_id': notice.orderId,
          'orderId': notice.orderId,
          if (notice.grocery) 'order_type': 'grocery',
        }),
      );
    } catch (error) {
      // A missing permission or a plugin that is not ready must never break
      // order tracking itself.
      log('Could not show the live order notification: $error');
    }
  }

  static Future<void> cancel(String orderId) async {
    try {
      await _plugin.cancel(notificationIdFor(orderId));
    } catch (error) {
      log('Could not clear the live order notification: $error');
    }
  }

  /// Applies one status push: shows or updates the ongoing notification, or
  /// removes it when the order has finished.
  static Future<void> handlePush(Map<String, dynamic> data) async {
    final finished = LiveOrderNotice.finishedOrderId(data);
    if (finished != null) {
      await cancel(finished);
      return;
    }
    final notice = LiveOrderNotice.fromPushData(data);
    if (notice != null) await show(notice);
  }

  static final Set<String> _shown = <String>{};

  /// Makes the shade match the orders the app currently knows are active:
  /// shows or updates each, clears the ones that are no longer active.
  static Future<void> sync(List<LiveOrderNotice> active) async {
    final ids = {for (final n in active) n.orderId};
    for (final gone in _shown.difference(ids).toList()) {
      await cancel(gone);
    }
    _shown
      ..clear()
      ..addAll(ids);
    for (final notice in active) {
      await show(notice);
    }
  }

  /// Signed out: nothing of the previous customer may stay in the shade.
  static Future<void> clearAll() async {
    for (final id in _shown.toList()) {
      await cancel(id);
    }
    _shown.clear();
  }
}
