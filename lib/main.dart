import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/push_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService().initialize();
    // Optional: Fetch token immediately for debugging
    await PushNotificationService().getToken();
  } catch (e) {
    debugPrint('Firebase initialization failed (run flutterfire configure): $e');
  }

  runApp(const ProviderScope(child: TurquoiseApp()));
}
