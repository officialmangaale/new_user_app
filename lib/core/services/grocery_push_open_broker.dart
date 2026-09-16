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

/// Hands tapped grocery notifications to the app root without depending on
/// Firebase, so a tap that launched the app is kept until the root is ready.
class GroceryPushOpenBroker {
  GroceryPushOpenBroker._();

  static final GroceryPushOpenBroker instance = GroceryPushOpenBroker._();

  GroceryOrderPushTarget? _pending;
  ValueChanged<GroceryOrderPushTarget>? _onOpen;

  void publishOpened(Map<String, dynamic> data) {
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

  void detach() => _onOpen = null;

  @visibleForTesting
  void reset() {
    _pending = null;
    _onOpen = null;
  }
}
