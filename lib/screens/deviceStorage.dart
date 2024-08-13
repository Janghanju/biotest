
import 'package:firebase_database/firebase_database.dart';

class DeviceStorage {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('devices');

  Future<void> saveDeviceInfo(String userId, String deviceId, String deviceName) async {
    try {
      await _dbRef.child(userId).set({
        'deviceId': deviceId,
        'deviceName': deviceName,
      });
    } catch (e) {
      print('Error saving device info: $e');
    }
  }

  Future<Map<String, String?>> loadDeviceInfo(String userId) async {
    try {
      DataSnapshot snapshot = await _dbRef.child(userId).get();
      if (snapshot.exists) {
        return Map<String, String>.from(snapshot.value as Map);
      }
    } catch (e) {
      print('Error loading device info: $e');
    }
    return {'deviceId': null, 'deviceName': null};
  }
}
