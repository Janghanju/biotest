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
  bool isScanning = false; // 스캔 상태 관리 변수

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
    if (!isScanning) { // 스캔 중복 방지
      setState(() {
        isScanning = true;
      });

      // Stream<List<ScanResult>>에 대해 listen을 사용하여 스캔 결과 처리
      flutterBlue.scanResults.listen((results) {
        setState(() {
          scanResults = results; // 스캔 결과 업데이트
        });
      });

      flutterBlue.startScan(timeout: Duration(seconds: 5)).then((value) {
        setState(() {
          isScanning = false; // 스캔 종료
        });
      }).catchError((error) {
        print("Scan error: $error");
        setState(() {
          isScanning = false;
        });
      });
    }
  }

  // 선택한 BLE 기기를 Firestore에 등록하는 메소드
  Future<void> registerDevice(BluetoothDevice device) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firestore에 사용자별로 기기 UUID 저장
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(device.id.toString())
            .set({'uuid': device.id.toString(), 'name': device.name});

        // 기기 등록 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device ${device.name} registered successfully')),
        );
      }
    } catch (e) {
      print("Device registration error: $e");
      // 등록 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register device')),
      );
    }
  }

  // 선택한 BLE 기기와 연결하는 메소드
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(); // 기기와 연결
      if (mounted) {
        setState(() {
          connectedDevice = device; // 연결된 기기 저장
        });
      }
      await discoverServices(device); // 기기의 서비스 탐색
    } catch (e) {
      print("Connection error: $e");
      // 연결 오류 처리
    }
  }

  // 연결된 기기의 서비스를 탐색하는 메소드
  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var c in service.characteristics) {
          if (c.uuid.toString() == "ec693074-43fe-489d-b63b-94456f83beb5") {
            if (mounted) {
              setState(() {
                characteristic = c; // 해당 특성 저장
              });
            }
            readCharacteristic(c); // 특성 값 읽기
          }
        }
      }
    } catch (e) {
      print("Service discovery error: $e");
      // 서비스 탐색 오류 처리
    }
  }

  // 특성 값을 읽는 메소드
  Future<void> readCharacteristic(BluetoothCharacteristic c) async {
    try {
      var value = await c.read(); // 특성 값 읽기
      print("Read value: $value"); // 값 출력
    } catch (e) {
      print("Read characteristic error: $e");
      // 읽기 오류 처리
    }
  }

  // 특성 값에 쓰기 작업을 수행하는 메소드
  Future<void> writeCharacteristic(BluetoothCharacteristic c) async {
    try {
      await c.write([0x01]); // 특성에 데이터 쓰기
      print("Write value: 0x01"); // 데이터 출력
    } catch (e) {
      print("Write characteristic error: $e");
      // 쓰기 오류 처리
    }
  }

  // Firestore에서 저장된 기기 UUID를 불러오는 메소드
  Future<List<String>> loadDeviceUuids() async {
    try {
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
    } catch (e) {
      print("Load UUID error: $e");
      // UUID 로드 오류 처리
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
            onTap: () => registerDevice(result.device), // 기기 선택 시 등록
          );
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                'Connected to ${connectedDevice!.name}'), // 연결된 기기 정보 표시
            ElevatedButton(
              onPressed: characteristic != null
                  ? () => writeCharacteristic(characteristic!)
                  : null,
              child: Text('Write to Characteristic'), // 특성에 쓰기 버튼
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
