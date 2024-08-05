import 'package:biotest/screens/fingerPrint.dart';
import 'package:biotest/screens/myPageScreen.dart';
import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/homescreen.dart';
import 'screens/login.dart';
import 'screens/signin.dart';
import 'screens/getItem.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initializeFirebase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bio_reactor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/signIn': (context) => SignUpPage(),
        '/home': (context) => HomeScreen(title: 'Bio-reactor Home Page'),
        '/getItem': (context) => DeviceAddPage(),
        '/ProfilePage': (context) => ProfilePage(),
        '/fingerPrint': (context) => FingerprintScreen()
      },
    );
  }
}

