import 'package:biotest/screens/BluetoothDeviceManager.dart';
import 'package:biotest/screens/SettingsScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/homescreen.dart';
import 'screens/login.dart';
import 'screens/signin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        '/signIn': (context) => SignInScreen(),
        '/home': (context) => HomeScreen(title: 'Bio-reactor'),
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}