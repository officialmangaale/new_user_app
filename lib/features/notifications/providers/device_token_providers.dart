import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_exception.dart';
import '../../../core/services/push_notification_service.dart';
import '../../orders/providers/orders_providers.dart';

/// Publishes the device's FCM token to `POST /notifications/device-token`.
///
/// The token is only useful to the backend once the customer is authenticated,
/// because the handler binds it to the caller's user id. Call this after a
/// successful OTP verification and on session restore.
///
/// Failures are swallowed deliberately: a device that cannot register push
/// must still be able to browse and order.
final deviceTokenRegistrarProvider = Provider<DeviceTokenRegistrar>((ref) {
  return DeviceTokenRegistrar(ref);
});

class DeviceTokenRegistrar {
  const DeviceTokenRegistrar(this._ref);

  final Ref _ref;

  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  Future<void> register() async {
    try {
      final token = await PushNotificationService().getToken();
      if (token == null || token.isEmpty) return;
      await _ref
          .read(accountRepositoryProvider)
          .registerDeviceToken(token: token, platform: _platform);
    } on ApiException catch (error) {
      log('Device token registration failed: ${error.message}');
    } catch (error) {
      log('Device token registration failed: $error');
    }
  }

  /// Best-effort de-registration before the session is cleared.
  Future<void> unregister() async {
    try {
      final token = await PushNotificationService().getToken();
      if (token == null || token.isEmpty) return;
      await _ref.read(accountRepositoryProvider).removeDeviceToken(token);
    } catch (error) {
      log('Device token removal failed: $error');
    }
  }
}
