import 'package:flutter/foundation.dart';

/// A grocery order that a tapped push notification asks the app to open.
@immutable
class GroceryOrderPushTarget {
  const GroceryOrderPushTarget(this.orderId);

  final String orderId;

  static final _idPattern = RegExp(r'^[0-9]{1,19}$');

  /// Reads a push `data` payload. Only customer grocery order notifications
  /// with a numeric grocery order id produce a target; food order
  /// notifications are handled by [FoodOrderPushTarget].
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

/// A food order that a tapped status notification asks the app to open.
@immutable
class FoodOrderPushTarget {
  const FoodOrderPushTarget(this.orderId);

  final String orderId;

  static final _idPattern = RegExp(r'^[0-9]{1,19}$');

  /// Only customer order-status notifications for a food order with a numeric
  /// id produce a target. Grocery orders use [GroceryOrderPushTarget].
  static FoodOrderPushTarget? fromData(Map<String, dynamic> data) {
    if (GroceryOrderPushTarget.fromData(data) != null) return null;
    if ('${data['order_type'] ?? ''}'.toLowerCase() == 'grocery') return null;
    final type = '${data['type'] ?? ''}'.toLowerCase();
    if (type != 'order_status_updated' && type != 'order_status') return null;
    final recipient = '${data['recipient_type'] ?? 'customer'}'.toLowerCase();
    if (recipient != 'customer') return null;
    final orderId = '${data['orderId'] ?? data['order_id'] ?? ''}'.trim();
    return _idPattern.hasMatch(orderId) ? FoodOrderPushTarget(orderId) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is FoodOrderPushTarget && other.orderId == orderId;

  @override
  int get hashCode => orderId.hashCode;
}

/// Hands tapped order notifications to the app root without depending on
/// Firebase, so a tap that launched the app is kept until the root is ready.
class GroceryPushOpenBroker {
  GroceryPushOpenBroker._();

  static final GroceryPushOpenBroker instance = GroceryPushOpenBroker._();

  GroceryOrderPushTarget? _pending;
  ValueChanged<GroceryOrderPushTarget>? _onOpen;
  FoodOrderPushTarget? _pendingFood;
  ValueChanged<FoodOrderPushTarget>? _onOpenFood;

  void publishOpened(Map<String, dynamic> data) {
    final food = FoodOrderPushTarget.fromData(data);
    if (food != null) {
      final foodListener = _onOpenFood;
      if (foodListener == null) {
        _pendingFood = food;
      } else {
        foodListener(food);
      }
      return;
    }
    final target = GroceryOrderPushTarget.fromData(data);
    if (target == null) return;
    final listener = _onOpen;
    if (listener == null) {
      _pending = target;
      return;
    }
    listener(target);
  }

  void attach(ValueChanged<GroceryOrderPushTarget> onOpen) {
    _onOpen = onOpen;
    final pending = _pending;
    _pending = null;
    if (pending != null) onOpen(pending);
  }

  void attachFood(ValueChanged<FoodOrderPushTarget> onOpen) {
    _onOpenFood = onOpen;
    final pending = _pendingFood;
    _pendingFood = null;
    if (pending != null) onOpen(pending);
  }

  void detach() {
    _onOpen = null;
    _onOpenFood = null;
  }

  @visibleForTesting
  void reset() {
    _pending = null;
    _onOpen = null;
    _pendingFood = null;
    _onOpenFood = null;
  }
}
