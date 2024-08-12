import 'package:biotest/screens/BluetoothDeviceManager.dart';
import 'package:biotest/screens/SettingsScreen.dart';
import 'package:biotest/screens/deviceStorage.dart';
import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/homescreen.dart';
import 'screens/login.dart';
import 'screens/signin.dart';
import 'screens/getItem.dart';

// Create instances of BluetoothDeviceManager and DeviceStorage
final BluetoothDeviceManager deviceManager = BluetoothDeviceManager();
final DeviceStorage deviceStorage = DeviceStorage();

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
        '/signIn': (context) => SignInScreen(),
        '/home': (context) => homeScreen(
          title: 'Bio-reactor',
          deviceManager: deviceManager, // Pass the instance here
          deviceStorage: deviceStorage, // Pass the instance here
        ),
        '/getItem': (context) => DeviceAddPage(),
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}


