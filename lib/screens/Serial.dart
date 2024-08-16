import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

bool isBluetoothTestRunning = false; // 플래그 변수

class BluetoothSerialCommunication extends StatefulWidget {
  @override
  _BluetoothSerialCommunicationState createState() => _BluetoothSerialCommunicationState();
}

class _BluetoothSerialCommunicationState extends State<BluetoothSerialCommunication> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? serialCharacteristic;
  List<Map<String, String>> registeredDevices = [];
  String? selectedDeviceUUID;
  String? selectedDeviceName;
  List<String> logMessages = []; // Log messages for serial monitor

  @override
  void initState() {
    super.initState();
    if (!isBluetoothTestRunning) { // 블루투스 테스트가 실행 중인지 확인
      isBluetoothTestRunning = true;
      loadRegisteredDevices();
    }
  }

  @override
  void dispose() {
    isBluetoothTestRunning = false; // 화면 종료 시 플래그 리셋
    flutterBlue.stopScan();
    connectedDevice?.disconnect();
    super.dispose();
  }

  // Firestore에서 등록된 기기 정보를 불러오기
  Future<void> loadRegisteredDevices() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .get();

      List<Map<String, String>> devices = [];
      for (var doc in snapshot.docs) {
        devices.add({
          'uuid': doc['uuid'],
          'name': doc['name'],
        });
      }

      if (mounted) {
        setState(() {
          registeredDevices = devices;
          if (devices.isNotEmpty) {
            selectedDeviceUUID = devices.first['uuid'];
            selectedDeviceName = devices.first['name'];
            connectToDevice();
          }
        });
      }
    }
  }

  // 저장된 UUID로 BLE 기기 연결
  Future<void> connectToDevice() async {
    if (selectedDeviceUUID != null) {
      try {
        await flutterBlue.startScan(timeout: Duration(seconds: 5));
        flutterBlue.scanResults.listen((results) async {
          for (ScanResult r in results) {
            if (r.device.id.toString() == selectedDeviceUUID) {
              try {
                await r.device.connect();
                setState(() {
                  connectedDevice = r.device;
                });
                await discoverServices(r.device);
                flutterBlue.stopScan();
                break;
              } catch (e) {
                setState(() {
                  logMessages.add("Connection error: $e");
                });
              }
            }
          }
        });
      } catch (e) {
        setState(() {
          logMessages.add("Scan start error: $e");
        });
      }
    }
  }

  // 기기의 서비스 탐색
  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "0000ffe1-0000-1000-8000-00805f9b34fb") {
          if (mounted) {
            setState(() {
              serialCharacteristic = characteristic;
              logMessages.add("Connected to ${device.name} (${device.id})");
            });
          }
          startListening();
        }
      }
    }
  }

  // 데이터 전송
  Future<void> sendData(String data) async {
    if (serialCharacteristic != null) {
      await serialCharacteristic!.write(utf8.encode(data));
      setState(() {
        logMessages.add("Sent: $data");
      });
    }
  }

  // 데이터 수신
  void startListening() {
    if (serialCharacteristic != null) {
      serialCharacteristic!.value.listen((value) {
        setState(() {
          logMessages.add("Received: ${utf8.decode(value)}");
        });
      });
      serialCharacteristic!.setNotifyValue(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("블루투스 테스트")),
      body: connectedDevice == null ? buildDeviceSelectionView() : buildCommunicationView(),
    );
  }

  // 등록된 기기 선택 뷰
  Widget buildDeviceSelectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: selectedDeviceUUID,
            onChanged: (String? newUUID) {
              if (mounted) {
                setState(() {
                  selectedDeviceUUID = newUUID;
                  selectedDeviceName = registeredDevices
                      .firstWhere((device) => device['uuid'] == newUUID)['name'];
                });
              }
            },
            items: registeredDevices.map<DropdownMenuItem<String>>((device) {
              return DropdownMenuItem<String>(
                value: device['uuid'],
                child: Text('${device['name']} (${device['uuid']})'),
              );
            }).toList(),
          ),
          ElevatedButton(
            onPressed: () {
              connectToDevice();
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }

  // 시리얼 통신 인터페이스
  Widget buildCommunicationView() {
    TextEditingController controller = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: logMessages.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(logMessages[index]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Enter message',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            sendData(controller.text);
            controller.clear();
          },
          child: Text('Send'),
        ),
      ],
    );
  }
}
