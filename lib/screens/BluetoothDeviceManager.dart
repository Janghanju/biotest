import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothDeviceRegistration extends StatefulWidget {
  BluetoothDeviceRegistration({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<BluetoothDeviceRegistration> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> deviceList = [];
  List<BluetoothService> _services = [];
  String _statusText = '';
  BluetoothCharacteristic? _targetCharacteristic;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    initBle();
  }

  // BLE 초기화 함수
  void initBle() {
    // BLE 스캔 상태 얻기 위한 리스너
    flutterBlue.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  // 권한 확인 함수 권한 없으면 권한 요청 화면 표시, 안드로이드만 해당
  _checkPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetooth,
      ].request();
      print(statuses[Permission.location]);
    }
  }

  // 장치 화면에 출력하는 위젯 함수
  Widget list() {
    return ListView.builder(
      itemCount: deviceList.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(deviceList[index].name),
          subtitle: Text(deviceList[index].id.toString()),
          onTap: () {
            connect(deviceList[index]);
          },
        );
      },
    );
  }

  // 스캔 함수
  void scan() async {
    if (!_isScanning) {
      deviceList.clear(); // 기존 장치 리스트 초기화
      // 스캔 시작
      await flutterBlue.startScan(timeout: Duration(seconds: 10));

      // 스캔 결과 구독
      flutterBlue.scanResults.listen((scanResults) {
        for (ScanResult scanResult in scanResults) {
          var device = scanResult.device;
          // 새로 발견된 장치만 추가
          if (!deviceList.contains(device)) {
            setState(() {
              deviceList.add(device);
            });
          }
        }
      });

      setState(() {
        _isScanning = true;
        setBLEState('Scanning');
      });
    } else {
      // 스캔 중이라면 스캔 정지
      flutterBlue.stopScan();
      setState(() {
        _isScanning = false;
        setBLEState('Stop Scan');
      });
    }
  }

  // BLE 연결 시 예외 처리를 위한 래핑 함수
  Future<void> _runWithErrorHandling(Future<void> Function() runFunction) async {
    try {
      await runFunction();
    } catch (e) {
      print("Error: $e");
    }
  }

  // 상태 변경하면서 페이지도 갱신하는 함수
  void setBLEState(String txt) {
    setState(() => _statusText = txt);
  }

  // 연결 함수
  void connect(BluetoothDevice device) async {
    if (_connectedDevice != null) {
      await _connectedDevice?.disconnect();
      return;
    }

    _runWithErrorHandling(() async {
      // 연결 시작
      await device.connect();
      setState(() {
        _connectedDevice = device;
        _statusText = 'Connected to ${device.name}';
      });

      // 서비스 및 캐릭터리스틱 검색
      _services = await device.discoverServices();
      for (var service in _services) {
        for (var characteristic in service.characteristics) {
          print('Characteristic: ${characteristic.uuid}');
          if (characteristic.properties.write || characteristic.properties.read) {
            _targetCharacteristic = characteristic;
          }
        }
      }
    });
  }

  // 데이터를 쓰는 함수
  void writeData(String data) async {
    if (_targetCharacteristic != null) {
      List<int> bytes = utf8.encode(data);
      await _targetCharacteristic!.write(bytes);
      print('Data written: $data');
    }
  }

  // 데이터를 읽는 함수
  void readData() async {
    if (_targetCharacteristic != null) {
      var value = await _targetCharacteristic!.read();
      print('Data read: ${utf8.decode(value)}');
    }
  }

  // 페이지 구성
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
              child: list(), // 리스트 출력
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton( // scan 버튼
                      onPressed: scan,
                      child: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton( // write 버튼
                      onPressed: () => writeData("Your WiFi SSID and Password here"),
                      child: Text("Write Data"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton( // read 버튼
                      onPressed: readData,
                      child: Text("Read Data"),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Text("State : "),
                  Expanded(
                    child: Text(
                      _statusText,
                      overflow: TextOverflow.ellipsis, // 텍스트가 길 경우 말줄임표 처리
                      maxLines: 1, // 최대 한 줄만 표시
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
