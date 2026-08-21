import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level background message handler for FCM.
/// This must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Handling a background message: ${message.messageId}');
  // You can process background data here (e.g. updating local database)
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() => _instance;

  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request permission for iOS/Android 13+
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    log('User granted permission: ${settings.authorizationStatus}');

    // 2. Setup local notifications for Android foreground display
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create a high importance channel for Android heads-up notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Set foreground notification presentation options for iOS
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Register foreground handler
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 6. Handle notification taps when app is in background but opened via tap
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 7. Check if app was opened from a terminated state via a notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }

    _isInitialized = true;
  }

  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      log('FCM Token: $token');
      // Typically you would send this token to your backend here
      return token;
    } catch (e) {
      log('Failed to get FCM token: $e');
      return null;
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    log('Received foreground message: ${message.messageId}');
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // name
            channelDescription:
                'This channel is used for important notifications.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    log('Message opened app: ${message.messageId}');
    // TODO: Handle navigation based on message.data if needed
    // Example: If message.data['orderId'] exists, navigate to tracking screen
  }

  void _onNotificationTapped(NotificationResponse response) {
    log('Local notification tapped: ${response.payload}');
    // TODO: Handle navigation from foreground tap
  }
}
