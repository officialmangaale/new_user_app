import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // IMPORTANT: You must run `flutterfire configure` to generate the correct
    // credentials for your Firebase project. This is a dummy file.
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured. '
      'Please run `flutterfire configure` at the root of your project.',
    );
  }
}
