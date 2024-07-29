import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart'; // Ensure you have your Firebase configuration file

class FirebaseService {
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (e.toString().contains('FirebaseApp with name [DEFAULT] already exists')) {
        print('Firebase already initialized');
      } else {
        rethrow;
      }
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
