import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

// BluetoothDeviceManager는 블루투스 기기와 연결 및 관리
class BluetoothDeviceManager {
  FlutterBlue flutterBlue = FlutterBlue.instance; // FlutterBlue 인스턴스
  BluetoothDevice? connectedDevice; // 현재 연결된 기기

  // 기기 검색 및 연결
  Future<void> scanAndConnect(String targetDeviceName) async {
    // 블루투스 사용 가능 여부 확인
    bool isAvailable = await flutterBlue.isAvailable;
    if (!isAvailable) {
      print('Bluetooth is not available');
      return;
    }

    // 블루투스 스캔 시작
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    // 스캔 결과 처리
    flutterBlue.scanResults.listen((results) {
      for (ScanResult result in results) {
        // 기기를 발견했을 때
        print('Discovered device: ${result.device.name}, ${result.device.id}');

        // 원하는 기기를 찾으면 연결
        if (result.device.name == targetDeviceName) {
          connectToDevice(result.device);
          flutterBlue.stopScan(); // 스캔 중지
          break;
        }
      }
    });
  }

  // 기기 연결
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      connectedDevice = device;
      print('Connected to device: ${device.name}');
    } catch (e) {
      print('Failed to connect to device: $e');
    }
  }

  // 기기 해제
  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        print('Disconnected from device: ${connectedDevice!.name}');
        connectedDevice = null;
      } catch (e) {
        print('Failed to disconnect device: $e');
      }
    }
  }

  // BLE 서비스 및 특성을 통해 Wi-Fi 자격 증명을 변경
  Future<void> changeWifiCredentials(String ssid, String password) async {
    if (connectedDevice == null) {
      print('No device connected');
      return;
    }

    try {
      List<BluetoothService> services = await connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == 'desired-characteristic-uuid') {
            // Wi-Fi 정보를 JSON 형식으로 인코딩
            Map<String, String> wifiInfo = {
              'ssid': ssid,
              'password': password,
            };
            String wifiInfoJson = jsonEncode(wifiInfo);

            // BLE 특성을 통해 와이파이 정보 전송
            await characteristic.write(utf8.encode(wifiInfoJson));
            print('Wi-Fi credentials sent successfully');
            return;
          }
        }
      }
      print('Desired characteristic not found');
    } catch (e) {
      print('Failed to change Wi-Fi credentials: $e');
    }
  }
}


