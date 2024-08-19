import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
    _fetchDeviceUUIDs();
  }

  Future<void> _fetchDeviceUUIDs() async {
    // Firestore에서 기기 UUID 목록 가져오기
    final firestoreDevices = await _fetchFirestoreDeviceUUIDs();

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

  Future<void> _downloadCSVFile() async {
    if (selectedDeviceUUID != null) {
      try {
        // Firebase Storage에서 파일 경로 지정
        final storageRef = FirebaseStorage.instance.ref().child('csv_files/${selectedDeviceUUID}.csv');
        final downloadURL = await storageRef.getDownloadURL();

        // 다운로드 URL을 통해 CSV 파일 다운로드를 수행
        // 일반적으로 다운로드는 특정 디렉토리에 저장하는 등의 추가 작업이 필요합니다.
        // 여기에서는 간단히 URL을 출력하도록 하겠습니다.
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
              onPressed: _downloadCSVFile,
              child: Text('CSV 파일 다운로드'),
            ),
          ],
        ),
      ),
    );
  }
}
