import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
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

    return statuses.values.every((status) => status.isGranted);
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
                      double.parse(ssidController.text), // rtRPM 값
                      true, // LED 값
                      7.0, // PH 값
                      25.0, // RT_Temp 값
                      5, // heatPow 값
                      75.0, // heatTemp 값
                      22.0, // inTemp 값
                      20.0, // outTemp 값
                      DateTime.now().millisecondsSinceEpoch // timestamp 값
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
      BluetoothDevice device,
      double rtRPM,
      bool LED,
      double PH,
      double RT_Temp,
      int heatPow,
      double heatTemp,
      double inTemp,
      double outTemp,
      int timestamp
      ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String uuid = device.id.toString();
        String firestorePath = 'users/${user.uid}/devices/$uuid';
        String realtimeDBPath = 'devices/$uuid';

        Map<String, dynamic> deviceData = {
          'uuid': uuid,
          'RT_RPM': rtRPM,
          'LED': LED,
          'PH': PH,
          'RT_Temp': RT_Temp,
          'temp/heatPow': heatPow,
          'temp/heatTemp': heatTemp,
          'temp/inTemp': inTemp,
          'temp/outTemp': outTemp,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Firestore에 저장
        await FirebaseFirestore.instance.doc(firestorePath).set(deviceData);

        // Realtime Database에 저장
        await FirebaseDatabase.instance.ref(realtimeDBPath).set(deviceData);

        // CSV 파일 생성 및 Storage에 업로드
        await _createAndUploadCSVFile(deviceData);

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

  Future<void> _createAndUploadCSVFile(Map<String, dynamic> deviceData) async {
    try {
      String uuid = deviceData['uuid'];
      String fileName = '$uuid.csv';

      // CSV 파일 내용 생성
      List<List<dynamic>> rows = [
        ['uuid', 'RT_RPM', 'LED', 'PH', 'RT_Temp', 'temp/heatPow', 'temp/heatTemp', 'temp/inTemp', 'temp/outTemp', 'timestamp'],
        [
          deviceData['uuid'],
          deviceData['RT_RPM'],
          deviceData['LED'],
          deviceData['PH'],
          deviceData['RT_Temp'],
          deviceData['temp/heatPow'],
          deviceData['temp/heatTemp'],
          deviceData['temp/inTemp'],
          deviceData['temp/outTemp'],
          deviceData['timestamp']
        ]
      ];

      String csvData = const ListToCsvConverter().convert(rows);

      // 임시 디렉토리에 CSV 파일 생성
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName';
      final file = File(path);
      String csvContent = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csvContent);

      // Firebase Storage에 업로드
      final storageRef = FirebaseStorage.instance.ref().child('csv_files/$fileName');
      await storageRef.putFile(file);

      print('CSV file uploaded: $fileName');
    } catch (e) {
      print('Failed to create or upload CSV file: $e');
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

