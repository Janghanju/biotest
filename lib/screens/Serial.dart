import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    loadRegisteredDevices();
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

      setState(() {
        registeredDevices = devices;
        if (devices.isNotEmpty) {
          selectedDeviceUUID = devices.first['uuid'];
        }
      });
    }
  }

  // BLE 기기 연결
  Future<void> connectToDevice() async {
    if (selectedDeviceUUID == null) return;

    flutterBlue.startScan(timeout: Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.id.toString() == selectedDeviceUUID) {
          await flutterBlue.stopScan();
          await result.device.connect();
          setState(() {
            connectedDevice = result.device;
          });
          discoverServices(result.device);
          break;
        }
      }
    });
  }

  // 기기의 서비스 탐색
  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == "0000ffe1-0000-1000-8000-00805f9b34fb") { // 예시 UUID
          setState(() {
            serialCharacteristic = characteristic;
          });
        }
      }
    }
  }

  // 데이터 전송
  Future<void> sendData(String data) async {
    if (serialCharacteristic != null) {
      await serialCharacteristic!.write(utf8.encode(data));
    }
  }

  // 데이터 수신
  void startListening() {
    if (serialCharacteristic != null) {
      serialCharacteristic!.value.listen((value) {
        print("Received: ${utf8.decode(value)}");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BLE Serial Communication")),
      body: connectedDevice == null ? buildDeviceSelectionView() : buildCommunicationView(),
    );
  }

  // 등록된 기기 선택 뷰
  Widget buildDeviceSelectionView() {
    return Column(
      children: [
        DropdownButton<String>(
          value: selectedDeviceUUID,
          onChanged: (String? newUUID) {
            setState(() {
              selectedDeviceUUID = newUUID;
            });
          },
          items: registeredDevices.map<DropdownMenuItem<String>>((device) {
            return DropdownMenuItem<String>(
              value: device['uuid'],
              child: Text(device['name']!),
            );
          }).toList(),
        ),
        ElevatedButton(
          onPressed: connectToDevice,
          child: Text('Connect to Device'),
        ),
      ],
    );
  }

  // 시리얼 통신 인터페이스
  Widget buildCommunicationView() {
    TextEditingController controller = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text('Connected to ${connectedDevice!.name}'),
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
        ElevatedButton(
          onPressed: startListening,
          child: Text('Start Listening'),
        ),
      ],
    );
  }
}
