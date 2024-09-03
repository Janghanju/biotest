import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';

class BluetoothDeviceRegistration extends StatefulWidget {
  BluetoothDeviceRegistration({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _BluetoothDeviceRegistrationState createState() => _BluetoothDeviceRegistrationState();
}

class _BluetoothDeviceRegistrationState extends State<BluetoothDeviceRegistration> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  bool _isScanning = false;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;
  List<BluetoothDevice> deviceList = [];
  BluetoothCharacteristic? _targetCharacteristic;

  String _ssid = '';
  String _password = '';
  String _dataToSend = ''; // 사용자가 입력할 데이터를 저장할 변수
  String _statusText = '';
  bool _showWifiCredentials = false; // WiFi Credentials 입력창을 동적으로 보여주기 위한 변수

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    initBle();
  }

  @override
  void dispose() {
    flutterBlue.stopScan();
    _disconnectDevice(); // 앱이 종료되거나 화면이 전환될 때 연결 해제
    super.dispose();
  }

  void initBle() {
    flutterBlue.isScanning.listen((isScanning) {
      if (mounted) {
        setState(() {
          _isScanning = isScanning;
        });
      }
    });
  }

  _checkPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
      ].request();
      print(statuses[Permission.location]);
    }
  }

  void scan() async {
    if (!_isScanning) {
      deviceList.clear();
      flutterBlue.startScan(timeout: Duration(seconds: 10)); // void를 반환하므로 따로 처리하지 않음

      flutterBlue.scanResults.listen((scanResults) {
        for (ScanResult scanResult in scanResults) {
          var device = scanResult.device;
          if (!deviceList.contains(device)) {
            if (mounted) {
              setState(() {
                deviceList.add(device);
                print("Device found: ${device.name.isNotEmpty ? device.name : 'Unknown Device'}, UUID: ${device.id}");
              });
            }
          }
        }
      });

      setState(() {
        _isScanning = true;
        setBLEState('Scanning');
      });
    } else {
      flutterBlue.stopScan(); // void를 반환하므로 따로 처리하지 않음
      setState(() {
        _isScanning = false;
        setBLEState('Stop Scan');
      });
    }
  }

  void setBLEState(String txt) {
    if (mounted) {
      setState(() => _statusText = txt);
    }
  }

  void connect(BluetoothDevice device) async {
    try {
      // 현재 연결 상태 확인
      var connectionState = await device.state.first;

      if (connectionState == BluetoothDeviceState.connected) {
        // 이미 연결된 경우, 연결 해제
        await device.disconnect();
        print("Existing connection with ${device.name} disconnected.");
      }

      await device.connect();
      if (mounted) {
        setState(() {
          _connectedDevice = device;
          _statusText = 'Connected to ${device.name}';
        });
      }

      var services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.read) {
            _targetCharacteristic = characteristic;
            if (characteristic.uuid.toString() == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
              setState(() {
                _characteristic = characteristic;
              });
            }
          }
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final deviceUUID = device.id.toString();

        // Save UUID to Realtime Database and sync with Firestore
        await DeviceRegistrationService().registerDeviceData(deviceUUID, userId);
      }

      setState(() {
        _statusText = 'Ready to send data';
        _showWifiCredentials = true; // WiFi Credentials 입력창을 표시
      });

      // 연결 후 알림창 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Connected to ${device.name}'),
              content: Container(
                height: 200,
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    ListTile(
                      title: Text('성공적으로 연결되었습니다.'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        _statusText = "Failed to connect: ${e.toString()}";
      });
    }
  }

  void _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        setState(() {
          _connectedDevice = null;
          _statusText = 'Disconnected';
          _showWifiCredentials = false; // WiFi Credentials 입력창 숨기기
        });
        print("Device disconnected successfully.");
      } catch (e) {
        print("Error during disconnection: $e");
      }
    }
  }

  void sendWifiCredentials() async {
    if (_characteristic != null) {
      String data = "$_ssid,$_password";
      List<int> bytes = utf8.encode(data);
      await _characteristic!.write(bytes);
      print("Data sent: $data");
    }
  }

  void sendDataToDevice() async {
    if (_characteristic != null && _dataToSend.isNotEmpty) {
      List<int> bytes = utf8.encode(_dataToSend);
      await _characteristic!.write(bytes);
      print("Custom Data sent: $_dataToSend");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: deviceList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(deviceList[index].name.isNotEmpty ? deviceList[index].name : 'Unknown Device'),
                  subtitle: Text(deviceList[index].id.toString()),
                  onTap: () {
                    connect(deviceList[index]);
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            child: Text("Scan for Devices"),
            onPressed: scan,
          ),
          if (_showWifiCredentials) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(labelText: "SSID"),
                onChanged: (value) {
                  setState(() {
                    _ssid = value;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
                onChanged: (value) {
                  setState(() {
                    _password = value;
                  });
                },
              ),
            ),
            ElevatedButton(
              child: Text("Send WiFi Credentials"),
              onPressed: _connectedDevice != null ? sendWifiCredentials : null,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(labelText: "Enter data to send"),
                onChanged: (value) {
                  setState(() {
                    _dataToSend = value;
                  });
                },
              ),
            ),
            ElevatedButton(
              child: Text("Send Data"),
              onPressed: _connectedDevice != null ? sendDataToDevice : null,
            ),
          ],
          ElevatedButton(
            child: Text("Disconnect"),
            onPressed: _disconnectDevice,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Text("State : "),
                Expanded(
                  child: Text(
                    _statusText,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceRegistrationService {
  Future<void> registerDeviceData(String deviceUUID, String userId) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('users/$userId/devices/$deviceUUID');

      Map<String, dynamic> deviceData = {
        "LED": true,
        "PH": 7.0,
        "PH2": 7.1,
        "RT_RPM": 1500,
        "RT_RPM2": 1600,
        "RT_Temp": 25.3,
        "RT_Temp2": 26.1,
        "UV": false,
        "set_RPM": 1200,
        "set_RPM2": 1250,
        "set_Temp": 24.0,
        "set_Temp2": 24.5,
        "temp": {
          "heatPow": 85,
          "heatTemp": 50.0,
          "inTemp": 22.0,
          "otzTemp": 23.0,
          "outTemp": 21.0,
          "outTemp2": 22.5
        },
        "timestamp": DateTime.now().millisecondsSinceEpoch
      };

      await databaseRef.set(deviceData);

      await _syncDataWithFirestore(deviceUUID, deviceData);

      await exportRealtimeDataToCsvAndUpload(deviceUUID, userId);

      print("Device data registered and CSV file uploaded successfully.");
    } catch (e) {
      print("Error registering device data: $e");
    }
  }

  Future<void> exportRealtimeDataToCsvAndUpload(String deviceUUID, String userId) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('users/$userId/devices/$deviceUUID');
      final snapshot = await databaseRef.get();

      if (snapshot.exists) {
        List<List<dynamic>> rows = [];

        rows.add([
          "Timestamp", "LED", "PH", "PH2", "RT_RPM", "RT_RPM2", "RT_Temp", "RT_Temp2", "UV",
          "set_RPM", "set_RPM2", "set_Temp", "set_Temp2", "temp/heatPow",
          "temp/heatTemp", "temp/inTemp", "temp/otzTemp", "temp/outTemp",
          "temp/outTemp2"
        ]);

        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        rows.add([
          data['timestamp'] ?? '',
          data['LED'] ?? '',
          data['PH'] ?? '',
          data['PH2'] ?? '',
          data['RT_RPM'] ?? '',
          data['RT_RPM2'] ?? '',
          data['RT_Temp'] ?? '',
          data['RT_Temp2'] ?? '',
          data['UV'] ?? '',
          data['set_RPM'] ?? '',
          data['set_RPM2'] ?? '',
          data['set_Temp'] ?? '',
          data['set_Temp2'] ?? '',
          data['temp']['heatPow'] ?? '',
          data['temp']['heatTemp'] ?? '',
          data['temp']['inTemp'] ?? '',
          data['temp']['otzTemp'] ?? '',
          data['temp']['outTemp'] ?? '',
          data['temp']['outTemp2'] ?? ''
        ]);

        String csv = const ListToCsvConverter().convert(rows);

        Uint8List csvBytes = Uint8List.fromList(csv.codeUnits);

        final storageRef = FirebaseStorage.instance.ref().child("users/$userId/devices/$deviceUUID.csv");
        await storageRef.putData(csvBytes);

        print("CSV 파일이 성공적으로 Firebase Storage에 업로드되었습니다.");
      } else {
        print("Realtime Database에서 데이터를 찾을 수 없습니다.");
      }
    } catch (e) {
      print("CSV 파일 생성 또는 업로드 중 오류 발생: $e");
    }
  }

  Future<void> _syncDataWithFirestore(String deviceUUID, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceUUID)
          .set(data, SetOptions(merge: true));

      print("Firestore에 데이터가 성공적으로 동기화되었습니다.");
    } catch (e) {
      print("Firestore 동기화 중 오류 발생: $e");
    }
  }

  Future<void> syncInitialData() async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('devices');
      final snapshot = await databaseRef.get();

      if (snapshot.exists) {
        Map<String, dynamic> devices = Map<String, dynamic>.from(snapshot.value as Map);
        devices.forEach((uuid, data) async {
          await FirebaseFirestore.instance
              .collection('devices')
              .doc(uuid)
              .set(data, SetOptions(merge: true));

          await exportRealtimeDataToCsvAndUpload(uuid, uuid);
        });
        print("초기 데이터 동기화 완료 및 CSV 파일 생성 완료");
      } else {
        print("Realtime Database에서 데이터를 찾을 수 없습니다.");
      }
    } catch (e) {
      print("초기 데이터 동기화 중 오류 발생: $e");
    }
  }
}
