// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
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
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBb6esUnta6kPxjr6-9vuLVdebjFGszcf0',
    appId: '1:499972106141:web:3def8b24d9bf8fbd773174',
    messagingSenderId: '499972106141',
    projectId: 'flutter-test-df9b9',
    authDomain: 'flutter-test-df9b9.firebaseapp.com',
    databaseURL: 'https://flutter-test-df9b9-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'flutter-test-df9b9.appspot.com',
    measurementId: 'G-CEP4PLG5V5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAn6a3XtpQY1fnk5mwR5wM4V4PfrpwMb8g',
    appId: '1:499972106141:android:8aa003ca8820b4de773174',
    messagingSenderId: '499972106141',
    projectId: 'flutter-test-df9b9',
    databaseURL: 'https://flutter-test-df9b9-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'flutter-test-df9b9.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDVe0jGUdJ4-a0H8AuenSlQyy9DkQ80qwc',
    appId: '1:499972106141:ios:e1fc6b96d45153b3773174',
    messagingSenderId: '499972106141',
    projectId: 'flutter-test-df9b9',
    databaseURL: 'https://flutter-test-df9b9-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'flutter-test-df9b9.appspot.com',
    iosBundleId: 'com.example.biotest',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDVe0jGUdJ4-a0H8AuenSlQyy9DkQ80qwc',
    appId: '1:499972106141:ios:e1fc6b96d45153b3773174',
    messagingSenderId: '499972106141',
    projectId: 'flutter-test-df9b9',
    databaseURL: 'https://flutter-test-df9b9-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'flutter-test-df9b9.appspot.com',
    iosBundleId: 'com.example.biotest',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBb6esUnta6kPxjr6-9vuLVdebjFGszcf0',
    appId: '1:499972106141:web:3e23a9d3d2569f80773174',
    messagingSenderId: '499972106141',
    projectId: 'flutter-test-df9b9',
    authDomain: 'flutter-test-df9b9.firebaseapp.com',
    databaseURL: 'https://flutter-test-df9b9-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'flutter-test-df9b9.appspot.com',
    measurementId: 'G-X3SDLNR7Z8',
  );

}