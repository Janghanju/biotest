import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/homescreen.dart';

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
      home: HomeScreen(title: 'Bio-reactor Home Page', cameraStreamUrl: '',),
    );
  }
}
