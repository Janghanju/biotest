import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:csv/csv.dart';

class DeviceRegistrationService {
  // Realtime Database에 기기 데이터를 등록
  Future<void> registerDeviceData(String deviceUUID) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('devices/$deviceUUID');

      // 기기 데이터 초기 구조 (이후에 주기적으로 변경될 수 있음)
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
        "timestamp": DateTime.now().millisecondsSinceEpoch // 현재 시간으로 타임스탬프 설정
      };

      // 데이터베이스에 저장
      await databaseRef.set(deviceData);

      // Firestore와 동기화
      await _syncDataWithFirestore(deviceUUID, deviceData);

      // CSV 파일 생성 및 Firebase Storage에 업로드
      await exportRealtimeDataToCsvAndUpload(deviceUUID);

      print("Device data registered and CSV file uploaded successfully.");
    } catch (e) {
      print("Error registering device data: $e");
    }
  }

  // 주기적으로 데이터를 가져와 CSV 파일로 저장 및 Firebase Storage에 업로드
  Future<void> exportRealtimeDataToCsvAndUpload(String deviceUUID) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('devices/$deviceUUID');
      final snapshot = await databaseRef.get();

      if (snapshot.exists) {
        List<List<dynamic>> rows = [];

        // CSV 파일에 추가할 데이터의 헤더
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

        // CSV 데이터를 메모리에서 Uint8List로 변환
        Uint8List csvBytes = Uint8List.fromList(csv.codeUnits);

        // Firebase Storage에 업로드
        final storageRef = FirebaseStorage.instance.ref().child("$deviceUUID.csv");
        await storageRef.putData(csvBytes);

        print("CSV 파일이 성공적으로 Firebase Storage에 업로드되었습니다.");
      } else {
        print("Realtime Database에서 데이터를 찾을 수 없습니다.");
      }
    } catch (e) {
      print("CSV 파일 생성 또는 업로드 중 오류 발생: $e");
    }
  }

  // Firestore와 데이터 동기화
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

  // 초기 데이터 동기화 (선택사항)
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

          // 각 기기의 CSV 파일을 생성하고 Firebase Storage에 업로드
          await exportRealtimeDataToCsvAndUpload(uuid);
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