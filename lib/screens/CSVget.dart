import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'DeviceRegistration.dart'; // DeviceRegistrationService를 포함한 파일

class DeviceRegistrationScreen extends StatefulWidget {
  @override
  _DeviceRegistrationScreenState createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  String? selectedDeviceUUID;
  String? selectedDeviceName;
  List<Map<String, String>> deviceList = [];

  @override
  void initState() {
    super.initState();
    _fetchAndSyncDeviceUUIDs();
  }

  Future<void> _fetchAndSyncDeviceUUIDs() async {
    // Firestore에서 기기 UUID 목록 가져오기
    final firestoreDevices = await _fetchFirestoreDeviceUUIDs();

    // Realtime Database에서 기기 UUID 목록 가져오기
    final realtimeDevices = await _fetchRealtimeDatabaseUUIDs();

    // Firestore와 Realtime Database를 동기화 (누락된 UUID 추가)
    for (var device in firestoreDevices) {
      if (!realtimeDevices.contains(device['uuid'])) {
        await _addDeviceToRealtimeDatabase(device['uuid']!, device['name']!);
      }
    }

    // 동기화된 UUID 목록 설정
    setState(() {
      deviceList = firestoreDevices;
      if (deviceList.isNotEmpty) {
        selectedDeviceUUID = deviceList[0]['uuid']; // 기본적으로 첫 번째 UUID 선택
        selectedDeviceName = deviceList[0]['name'];
      }
    });
  }

  Future<List<Map<String, String>>> _fetchFirestoreDeviceUUIDs() async {
    List<Map<String, String>> devices = [];
    final firestoreRef = FirebaseFirestore.instance.collection('devices');
    final snapshot = await firestoreRef.get();
    for (var doc in snapshot.docs) {
      devices.add({'uuid': doc.id, 'name': doc['name']});
    }
    return devices;
  }

  Future<List<String>> _fetchRealtimeDatabaseUUIDs() async {
    List<String> uuids = [];
    final databaseRef = FirebaseDatabase.instance.ref('devices');
    final snapshot = await databaseRef.get();
    if (snapshot.exists) {
      Map<String, dynamic> devices = Map<String, dynamic>.from(snapshot.value as Map);
      devices.forEach((key, value) {
        uuids.add(key);
      });
    }
    return uuids;
  }

  Future<void> _addDeviceToRealtimeDatabase(String uuid, String name) async {
    final databaseRef = FirebaseDatabase.instance.ref('devices/$uuid');
    // 기본 데이터 구조를 추가하거나 Firestore의 데이터를 가져와 추가할 수 있음
    Map<String, dynamic> defaultData = {
      "LED": false,
      "PH": 0.0,
      "PH2": 0.0,
      "RT_RPM": 0,
      "RT_RPM2": 0,
      "RT_Temp": 0.0,
      "RT_Temp2": 0.0,
      "UV": false,
      "set_RPM": 0,
      "set_RPM2": 0,
      "set_Temp": 0.0,
      "set_Temp2": 0.0,
      "temp": {
        "heatPow": 0,
        "heatTemp": 0.0,
        "inTemp": 0.0,
        "otzTemp": 0.0,
        "outTemp": 0.0,
        "outTemp2": 0.0
      },
      "name": name,
      "timestamp": DateTime.now().millisecondsSinceEpoch
    };
    await databaseRef.set(defaultData);
  }

  Future<void> _exportAndSyncData() async {
    if (selectedDeviceUUID != null) {
      DeviceRegistrationService service = DeviceRegistrationService();
      await service.exportRealtimeDataToCsvAndUpload(selectedDeviceUUID!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('CSV 파일 생성 및 동기화')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              isExpanded: true,
              value: selectedDeviceUUID,
              onChanged: (String? newUUID) {
                setState(() {
                  selectedDeviceUUID = newUUID;
                  selectedDeviceName = deviceList
                      .firstWhere((device) => device['uuid'] == newUUID)['name'];
                });
              },
              items: deviceList.map<DropdownMenuItem<String>>((device) {
                return DropdownMenuItem<String>(
                  value: device['uuid'],
                  child: Text('${device['name']} (${device['uuid']})'),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _exportAndSyncData,
              child: Text('CSV 파일 생성 및 데이터 동기화'),
            ),
          ],
        ),
      ),
    );
  }
}