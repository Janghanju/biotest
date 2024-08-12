import 'package:shared_preferences/shared_preferences.dart';

// DeviceStorage는 로컬에 기기 정보를 저장하고 불러오는 클래스
class DeviceStorage {
  static const String deviceIdKey = 'deviceId';
  static const String deviceNameKey = 'deviceName';

  // 기기 정보 저장
  Future<void> saveDeviceInfo(String deviceId, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(deviceIdKey, deviceId);
    await prefs.setString(deviceNameKey, deviceName);
  }

  // 기기 정보 로드
  Future<Map<String, String?>> loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'deviceId': prefs.getString(deviceIdKey),
      'deviceName': prefs.getString(deviceNameKey),
    };
  }
}

