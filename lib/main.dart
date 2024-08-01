import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/homescreen.dart';
import 'screens/login_screen.dart';
import 'screens/signin_screen.dart';

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
        '/signin': (context) => SignInScreen(),
        '/home': (context) => HomeScreen(title: 'Bio-reactor Home Page', cameraStreamUrl: '',),
        '/getItem': (context) => GetItemScreen(),
      },
    );
  }
}
