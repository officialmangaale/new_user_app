import 'package:flutter/foundation.dart';

/// A grocery order that a tapped push notification asks the app to open.
@immutable
class GroceryOrderPushTarget {
  const GroceryOrderPushTarget(this.orderId);

  final String orderId;

  static final _idPattern = RegExp(r'^[0-9]{1,19}$');

  /// Reads a push `data` payload. Only customer grocery order notifications
  /// with a numeric grocery order id produce a target; food order
  /// notifications keep their existing behaviour and are ignored here.
  static GroceryOrderPushTarget? fromData(Map<String, dynamic> data) {
    final isGroceryOrder =
        data['action_type'] == 'openGroceryOrder' ||
        (data['order_type'] == 'grocery' &&
            data['recipient_type'] == 'customer');
    if (!isGroceryOrder) return null;
    final orderId =
        (data['orderId'] ?? data['grocery_order_id'])?.toString().trim() ?? '';
    return _idPattern.hasMatch(orderId) ? GroceryOrderPushTarget(orderId) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is GroceryOrderPushTarget && other.orderId == orderId;

  @override
  int get hashCode => orderId.hashCode;
}

/// Where a tapped push notification asks the app to go, as an in-app route.
///
/// Understands three payload shapes, each validated so a crafted payload can
/// only ever reach a known route with a numeric id:
///  * grocery order  -> `/tracking/<id>?mode=grocery`
///  * food order status (`type: order_status_updated`, customer recipient)
///    -> `/tracking/<id>`
///  * product / promotion (`action_type: openProduct`, or `type` product /
///    promotion, with `product_id`) -> `/product/<id>` (grocery, the default)
///    or `/food-item/<id>` (`item_type: food`), with an optional numeric
///    `campaign_id` (kept in [campaignId], not in the route) for attribution.
@immutable
class PushOpenTarget {
  const PushOpenTarget(this.location, {this.campaignId});

  final String location;

  /// The admin promotional campaign that produced this push, when it did. It is
  /// kept out of [location] and remembered for order attribution instead.
  final int? campaignId;

  static final _idPattern = RegExp(r'^[0-9]{1,19}$');

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static PushOpenTarget? fromData(Map<String, dynamic> data) {
    final grocery = GroceryOrderPushTarget.fromData(data);
    if (grocery != null) {
      return PushOpenTarget('/tracking/${grocery.orderId}?mode=grocery');
    }

    final isProduct = data['action_type'] == 'openProduct' ||
        data['type'] == 'product' ||
        data['type'] == 'promotion';
    if (isProduct) {
      final productId = _text(data['product_id'] ?? data['productId']);
      if (!_idPattern.hasMatch(productId)) return null;
      final base = _text(data['item_type']) == 'food'
          ? '/food-item/$productId'
          : '/product/$productId';
      final campaignId = _text(data['campaign_id'] ?? data['campaignId']);
      return PushOpenTarget(
        base,
        campaignId: _idPattern.hasMatch(campaignId)
            ? int.tryParse(campaignId)
            : null,
      );
    }

    final isFoodOrderUpdate = data['recipient_type'] == 'customer' &&
        (data['type'] == 'order_status_updated' ||
            data['action_type'] == 'openOrder');
    if (isFoodOrderUpdate) {
      final orderId = _text(data['orderId'] ?? data['order_id']);
      if (_idPattern.hasMatch(orderId)) return PushOpenTarget('/tracking/$orderId');
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PushOpenTarget &&
      other.location == location &&
      other.campaignId == campaignId;

  @override
  int get hashCode => Object.hash(location, campaignId);
}

/// Hands tapped notifications to the app root without depending on Firebase,
/// so a tap that launched the app is kept until the root is ready.
class GroceryPushOpenBroker {
  GroceryPushOpenBroker._();

  static final GroceryPushOpenBroker instance = GroceryPushOpenBroker._();

  PushOpenTarget? _pending;
  ValueChanged<PushOpenTarget>? _onOpen;

  void publishOpened(Map<String, dynamic> data) {
    final target = PushOpenTarget.fromData(data);
    if (target == null) return;
    final listener = _onOpen;
    if (listener == null) {
      _pending = target;
      return;
    }
    listener(target);
  }

  void attach(ValueChanged<PushOpenTarget> onOpen) {
    _onOpen = onOpen;
    final pending = _pending;
    _pending = null;
    if (pending != null) onOpen(pending);
  }

  void detach() => _onOpen = null;

  @visibleForTesting
  void reset() {
    _pending = null;
    _onOpen = null;
  }
}
