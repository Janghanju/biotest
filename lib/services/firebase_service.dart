import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';

class FirebaseService {
  static FirebaseApp? _firebaseApp;

  static Future<void> initializeFirebase() async {
    if (_firebaseApp == null) {
      try {
        _firebaseApp = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('Firebase initialized');
      } catch (e) {
        if (e.toString().contains('FirebaseApp with name [DEFAULT] already exists')) {
          print('Firebase already initialized');
        } else {
          rethrow;
        }
      }
    } else {
      print('Firebase already initialized');
    }
  }

  static Future<String?> getFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      return fcmToken;
    } catch (e) {
      print('Failed to get FCM token: $e');
      return null;
    }
  }
}

