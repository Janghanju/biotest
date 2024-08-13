import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    loadDeviceUuids().then((uuids) {
      autoConnectDevices(uuids); // 저장된 UUID로 자동 연결 시도
    });
    startScan(); // 새로운 기기를 찾기 위해 스캔 시작
  }

  // 기기 스캔을 시작하는 메소드
  void startScan() {
    // Stream<List<ScanResult>>에 대해 listen을 사용하여 스캔 결과 처리
    flutterBlue.scanResults.listen((results) {
      setState(() {
        scanResults = results; // 스캔 결과 업데이트
      });
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5)); // 스캔 시작
  }


  // 선택한 BLE 기기와 연결하는 메소드
  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect(); // 기기와 연결
    setState(() {
      connectedDevice = device; // 연결된 기기 저장
    });
    await discoverServices(device); // 기기의 서비스 탐색
    await saveDeviceUuid(device.id.toString()); // 연결된 기기의 UUID 저장
  }

  // 연결된 기기의 서비스를 탐색하는 메소드
  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var c in service.characteristics) {
        if (c.uuid.toString() == "ec693074-43fe-489d-b63b-94456f83beb5") { //기기의 특성(characteristic) UUID를 확인하여 특정 특성이 발견되었을 때 특정 작업을 수행하도록 하는 코드
          setState(() {
            characteristic = c; // 해당 특성 저장
          });
          readCharacteristic(c); // 특성 값 읽기
        }
      }
    }
  }

  // 특성 값을 읽는 메소드
  Future<void> readCharacteristic(BluetoothCharacteristic c) async {
    var value = await c.read(); // 특성 값 읽기
    print("Read value: $value"); // 값 출력
  }

  // 특성 값에 쓰기 작업을 수행하는 메소드
  Future<void> writeCharacteristic(BluetoothCharacteristic c) async {
    await c.write([0x01]); // 특성에 데이터 쓰기
    print("Write value: 0x01"); // 데이터 출력
  }

  // Firestore에 기기 UUID를 저장하는 메소드
  Future<void> saveDeviceUuid(String deviceUuid) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Firestore에 사용자별로 기기 UUID 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceUuid)
          .set({'uuid': deviceUuid});
    }
  }

  // Firestore에서 저장된 기기 UUID를 불러오는 메소드
  Future<List<String>> loadDeviceUuids() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .get();

      List<String> deviceUuids = [];
      for (var doc in snapshot.docs) {
        deviceUuids.add(doc['uuid']); // UUID를 목록에 추가
      }
      return deviceUuids;
    }
    return [];
  }

  // 저장된 UUID로 자동 연결을 시도하는 메소드
  void autoConnectDevices(List<String> deviceUuids) {
    flutterBlue.scanResults.listen((scanResults) {
      for (ScanResult result in scanResults) {
        if (deviceUuids.contains(result.device.id.toString())) {
          connectToDevice(result.device); // UUID가 일치하는 기기와 연결
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
          ? ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          var result = scanResults[index];
          return ListTile(
            title: Text(result.device.name),
            subtitle: Text(result.device.id.toString()),
            onTap: () => connectToDevice(result.device), // 기기 선택 시 연결
          );
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Connected to ${connectedDevice!.name}'), // 연결된 기기 정보 표시
            ElevatedButton(
              onPressed: characteristic != null
                  ? () => writeCharacteristic(characteristic!)
                  : null,
              child: Text('Write to Characteristic'), // 특성에 쓰기 버튼
            ),
          ],
        ),
      ),
    );
  }
}



