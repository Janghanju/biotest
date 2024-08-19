import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothDeviceRegistration extends StatefulWidget {
  @override
  _BluetoothDeviceRegistrationState createState() =>
      _BluetoothDeviceRegistrationState();
}

class _BluetoothDeviceRegistrationState
    extends State<BluetoothDeviceRegistration> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? characteristic;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    requestPermissions().then((granted) {
      if (granted) {
        loadDeviceUuids().then((uuids) {
          autoConnectDevices(uuids);
        });
        startScan();
      } else {
        print("Bluetooth permissions not granted");
      }
    });
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    return allGranted;
  }

  void startScan() {
    if (!isScanning) {
      setState(() {
        isScanning = true;
      });

      flutterBlue.scanResults.listen((results) {
        setState(() {
          scanResults = results;
        });
      });

      flutterBlue.startScan(timeout: Duration(seconds: 5)).then((value) {
        setState(() {
          isScanning = false;
        });
      }).catchError((error) {
        print("Scan error: $error");
        setState(() {
          isScanning = false;
        });
      });
    }
  }

  Future<void> registerDevice(BluetoothDevice device) async {
    TextEditingController ssidController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Wi-Fi Credentials'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssidController,
                decoration: InputDecoration(labelText: 'Wi-Fi SSID'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Wi-Fi Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (ssidController.text.isNotEmpty &&
                    passwordController.text.isNotEmpty) {
                  await _saveDeviceData(
                    device,
                    ssidController.text,
                    passwordController.text,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter valid credentials')),
                  );
                }
              },
              child: Text('Register'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDeviceData(
      BluetoothDevice device, String ssid, String password) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String firestorePath = 'users/${user.uid}/devices/${device.id.toString()}';
        String realtimeDBPath = 'devices/${device.id.toString()}';

        Map<String, dynamic> deviceData = {
          'uuid': device.id.toString(),
          'name': device.name,
          'wifi_ssid': ssid,
          'wifi_password': password,
          'timestamp': DateTime.now().millisecondsSinceEpoch, // 추가된 타임스탬프
        };

        // Firestore에 저장
        await FirebaseFirestore.instance.doc(firestorePath).set(deviceData);

        // Realtime Database에 저장
        await FirebaseDatabase.instance.ref(realtimeDBPath).set(deviceData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device ${device.name} registered successfully')),
        );
      }
    } catch (e) {
      print("Device registration error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register device')),
      );
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      if (mounted) {
        setState(() {
          connectedDevice = device;
        });
      }
      await discoverServices(device);
    } catch (e) {
      print("Connection error: $e");
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var c in service.characteristics) {
          if (c.uuid.toString() == "ec693074-43fe-489d-b63b-94456f83beb5") {
            if (mounted) {
              setState(() {
                characteristic = c;
              });
            }
            readCharacteristic(c);
          }
        }
      }
    } catch (e) {
      print("Service discovery error: $e");
    }
  }

  Future<void> readCharacteristic(BluetoothCharacteristic c) async {
    try {
      var value = await c.read();
      print("Read value: $value");
    } catch (e) {
      print("Read characteristic error: $e");
    }
  }

  Future<void> writeCharacteristic(BluetoothCharacteristic c) async {
    try {
      await c.write([0x01]);
      print("Write value: 0x01");
    } catch (e) {
      print("Write characteristic error: $e");
    }
  }

  Future<List<String>> loadDeviceUuids() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPath = 'users/${user.uid}/devices';
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection(userPath)
            .get();

        List<String> deviceUuids = [];
        for (var doc in snapshot.docs) {
          deviceUuids.add(doc['uuid']);
        }
        return deviceUuids;
      }
    } catch (e) {
      print("Load UUID error: $e");
    }
    return [];
  }

  void autoConnectDevices(List<String> deviceUuids) {
    flutterBlue.scanResults.listen((scanResults) {
      for (ScanResult result in scanResults) {
        if (deviceUuids.contains(result.device.id.toString())) {
          connectToDevice(result.device);
          break;
        }
      }
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BLE Device Registration'),
      ),
      body: connectedDevice == null
          ? scanResults.isEmpty
          ? Center(child: Text('No devices found.'))
          : ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          var result = scanResults[index];
          String deviceName = result.device.name.isNotEmpty
              ? result.device.name
              : 'Unknown Device';
          return ListTile(
            title: Text(deviceName),
            subtitle: Text(result.device.id.toString()),
            onTap: () => registerDevice(result.device),
          );
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Connected to ${connectedDevice!.name}'),
            ElevatedButton(
              onPressed: characteristic != null
                  ? () => writeCharacteristic(characteristic!)
                  : null,
              child: Text('Write to Characteristic'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: startScan,
        child: Icon(Icons.refresh),
      ),
    );
  }
}
