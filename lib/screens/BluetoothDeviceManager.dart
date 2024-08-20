import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';


class BluetoothDeviceRegistration extends StatefulWidget {
  final String title;

  BluetoothDeviceRegistration({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<BluetoothDeviceRegistration> {
  FlutterBlue _flutterBlue = FlutterBlue.instance;
  bool _isScanning = false;
  bool _connected = false;
  BluetoothDevice? _curPeripheral;
  List<BleDeviceItem> deviceList = [];
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    init();
  }

  // BLE 초기화 함수
  void init() async {
    await _checkPermissions();
    _flutterBlue.state.listen((state) {
      if (state == BluetoothState.on) {
        print("Bluetooth is ON");
      } else if (state == BluetoothState.off) {
        print("Bluetooth is OFF");
      }
    });
  }

  // 권한 확인 함수
  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
      ].request();

      if (statuses.values.any((status) => !status.isGranted)) {
        print("Permissions not granted");
      }
    }
  }

  // 장치 화면에 출력하는 위젯 함수
  Widget list() {
    return ListView.builder(
      itemCount: deviceList.length,
      itemBuilder: (context, index) {
        final device = deviceList[index];
        return ListTile(
          title: Text(device.deviceName.isNotEmpty ? device.deviceName : "Unknown Device"),
          subtitle: Text(device.device.id.toString()),
          trailing: Text("${device.rssi}"),
          onTap: () => connect(index),
        );
      },
    );
  }

  // scan 함수
  void scan() async {
    if (!_isScanning) {
      deviceList.clear();
      _flutterBlue.startScan(timeout: Duration(seconds: 4));

      _flutterBlue.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (!deviceList.any((element) => element.device.id == r.device.id)) {
            setState(() {
              deviceList.add(BleDeviceItem(r.device.name, r.rssi, r.device));
            });
          }
        }
      });

      setState(() {
        _isScanning = true;
        setBLEState('Scanning');
      });
    } else {
      await _flutterBlue.stopScan();
      setState(() {
        _isScanning = false;
        setBLEState('Stop Scan');
      });
    }
  }

  // 상태 변경하면서 페이지도 갱신하는 함수
  void setBLEState(String txt) {
    setState(() => _statusText = txt);
  }

  // 연결 함수
  Future<void> connect(int index) async {
    if (_connected) {
      await _curPeripheral?.disconnect();
      setState(() {
        _connected = false;
        _curPeripheral = null;
        setBLEState('Disconnected');
      });
      return;
    }

    final device = deviceList[index].device;

    device.state.listen((connectionState) {
      switch (connectionState) {
        case BluetoothDeviceState.connected:
          _curPeripheral = device;
          setBLEState('Connected');
          break;
        case BluetoothDeviceState.connecting:
          setBLEState('Connecting');
          break;
        case BluetoothDeviceState.disconnected:
          _connected = false;
          setBLEState('Disconnected');
          break;
        case BluetoothDeviceState.disconnecting:
          setBLEState('Disconnecting');
          break;
      }
    });

    await device.connect();
    setState(() {
      _connected = true;
      setBLEState('Connected');
    });

    // Discover services and characteristics
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) async {
      List<BluetoothCharacteristic> characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        print("Characteristic UUID: ${c.uuid}");
        // 여기서 특성(characteristics)을 읽거나 쓰거나 할 수 있습니다.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: list(),
            ),
            Container(
              child: Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: scan,
                    child: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
                  ),
                  SizedBox(width: 10),
                  Text("State: "),
                  Text(_statusText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// BLE 장치 정보 저장 클래스
class BleDeviceItem {
  String deviceName;
  BluetoothDevice device;
  int rssi;

  BleDeviceItem(this.deviceName, this.rssi, this.device);
}
