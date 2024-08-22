import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';

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

  @override
  void dispose() {
    // FlutterBlue와 관련된 리스너 또는 스트림을 정리
    flutterBlue.stopScan();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  // BLE 초기화 함수
  void initBle() {
    // BLE 스캔 상태 얻기 위한 리스너
    flutterBlue.isScanning.listen((isScanning) {
      if (mounted) {
        setState(() {
          _isScanning = isScanning;
        });
      }
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
          var name = device.name.isNotEmpty
              ? device.name
              : scanResult.advertisementData.localName.isNotEmpty
              ? scanResult.advertisementData.localName
              : 'Unknown Device';

          // 새로 발견된 장치만 추가
          if (!deviceList.contains(device)) {
            if (mounted) {
              setState(() {
                deviceList.add(device);
                print("Device found: $name, UUID: ${device.id}");
              });

              // 스캔 중지 및 연결 시도
              flutterBlue.stopScan();
              _isScanning = false;
              setBLEState('Connecting to $name');
              connect(device);
            }
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
    if (mounted) {
      setState(() => _statusText = txt);
    }
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
      if (mounted) {
        setState(() {
          _connectedDevice = device;
          _statusText = 'Connected to ${device.name}';
        });
      }

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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final deviceUUID = device.id.toString();

        // Save UUID to Realtime Database and sync with Firestore
        await DeviceRegistrationService().registerDeviceData(deviceUUID, userId);
      }

      // 연결 후 채팅창 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Connected to ${device.name}'),
              content: Container(
                height: 200, // 고정된 높이 설정
                width: double.maxFinite, // 가능한 최대 너비 설정
                child: ListView(
                  shrinkWrap: true, // 필요한 크기에 맞게 자동으로 크기를 조절
                  children: <Widget>[
                    ListTile(
                      title: Text('성공적으로 연결되었습니다.'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Close'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  // 데이터를 쓰는 함수
  void writeData(String data) async {
    if (_targetCharacteristic != null) {
      try {
        List<int> bytes = utf8.encode(data);
        await _targetCharacteristic!.write(bytes);
        print('Data written: $data');
      } catch (e) {
        print("Write Error: $e");
      }
    } else {
      print("No characteristic found for writing.");
    }
  }

  // 데이터를 읽는 함수
  void readData() async {
    if (_targetCharacteristic != null) {
      try {
        var value = await _targetCharacteristic!.read();
        print('Data read: ${utf8.decode(value)}');
      } catch (e) {
        print("Read Error: $e");
      }
    } else {
      print("No characteristic found for reading.");
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
                    child: ElevatedButton(
                      // scan 버튼
                      onPressed: scan,
                      child: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      // write 버튼
                      onPressed: () => writeData("Your WiFi SSID and Password here"),
                      child: Text("Write Data"),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      // read 버튼
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

// 간단한 채팅 UI를 위한 위젯
class ChatScreen extends StatefulWidget {
  final Function(String) writeCallback;

  ChatScreen({required this.writeCallback});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<String> messages = ["Device: Hi there!"];
  TextEditingController _controller = TextEditingController();

  void _sendMessage(String message) {
    if (message.isNotEmpty) {
      setState(() {
        messages.add("You: $message");
      });
      widget.writeCallback(message); // 메시지 전송
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200, // 채팅창 높이 설정
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Type your message...',
            ),
            onSubmitted: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// Realtime Database와 Firebase Storage에 데이터를 저장하는 서비스 클래스
class DeviceRegistrationService {
  // Realtime Database에 기기 데이터를 등록하고 Firestore와 동기화
  Future<void> registerDeviceData(String deviceUUID, String userId) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('users/$userId/devices/$deviceUUID');

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
      await exportRealtimeDataToCsvAndUpload(deviceUUID, userId);

      print("Device data registered and CSV file uploaded successfully.");
    } catch (e) {
      print("Error registering device data: $e");
    }
  }

  // 주기적으로 데이터를 가져와 CSV 파일로 저장 및 Firebase Storage에 업로드
  Future<void> exportRealtimeDataToCsvAndUpload(String deviceUUID, String userId) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('users/$userId/devices/$deviceUUID');
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
        final storageRef = FirebaseStorage.instance.ref().child("users/$userId/devices/$deviceUUID.csv");
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
          await exportRealtimeDataToCsvAndUpload(uuid, uuid);
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
