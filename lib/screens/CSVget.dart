import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  @override
  _DeviceRegistrationScreenState createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  String? selectedDeviceUUID;
  List<Map<String, String>> deviceList = [];

  @override
  void initState() {
    super.initState();
    _fetchDeviceUUIDs();
  }

  Future<void> _fetchDeviceUUIDs() async {
    // Firestore에서 기기 UUID 목록 가져오기
    final firestoreDevices = await _fetchFirestoreDeviceUUIDs();

    setState(() {
      deviceList = firestoreDevices;
      if (deviceList.isNotEmpty) {
        selectedDeviceUUID = deviceList[0]['uuid']; // 기본적으로 첫 번째 UUID 선택
      }
    });
  }

  Future<List<Map<String, String>>> _fetchFirestoreDeviceUUIDs() async {
    List<Map<String, String>> devices = [];
    final firestoreRef = FirebaseFirestore.instance.collection('devices');
    final snapshot = await firestoreRef.get();
    for (var doc in snapshot.docs) {
      devices.add({'uuid': doc.id});
    }
    return devices;
  }

  Future<void> _downloadCSVFile() async {
    if (selectedDeviceUUID != null) {
      try {
        // 사용자 ID 가져오기
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          Fluttertoast.showToast(msg: "로그인이 필요합니다");
          return;
        }

        // Firebase Storage에서 파일 경로 지정
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/$userId/devices/${selectedDeviceUUID}.csv');
        final downloadURL = await storageRef.getDownloadURL();

        // 다운로드 URL을 통해 CSV 파일 다운로드를 수행
        print('Download URL: $downloadURL');

        Fluttertoast.showToast(msg: "CSV 파일 다운로드 완료");
      } catch (e) {
        // 파일이 없을 경우 오류 처리
        Fluttertoast.showToast(msg: "파일이 없습니다");
      }
    } else {
      Fluttertoast.showToast(msg: "UUID가 선택되지 않았습니다");
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
                });
              },
              items: deviceList.map<DropdownMenuItem<String>>((device) {
                return DropdownMenuItem<String>(
                  value: device['uuid'],
                  child: Text('(${device['uuid']})'),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _downloadCSVFile,
              child: Text('CSV 파일 다운로드'),
            ),
          ],
        ),
      ),
    );
  }
}
