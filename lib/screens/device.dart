import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class DeviceScreen extends StatefulWidget {
  DeviceScreen({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  // flutterBlue 인스턴스 생성
  FlutterBlue flutterBlue = FlutterBlue.instance;

  // 연결 상태 표시 문자열
  String stateText = 'Connecting';

  // 연결 버튼 문자열
  String connectButtonText = 'Disconnect';

  // 현재 연결 상태 저장용
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;

  // 연결 상태 리스너 핸들 화면 종료 시 리스너 해제를 위함
  StreamSubscription<BluetoothDeviceState>? _stateListener;

  List<BluetoothService> bluetoothService = [];
  Map<String, List<int>> notifyDatas = {};

  @override
  void initState() {
    super.initState();
    // 상태 연결 리스너 등록
    _stateListener = widget.device.state.listen((event) {
      if (deviceState != event) {
        // 상태가 변경되었을 때만 업데이트
        setBleConnectionState(event);
      }
    });
    // 연결 시작
    connect();
  }

  @override
  void dispose() {
    // 상태 리스너 해제
    _stateListener?.cancel();
    // 연결 해제
    disconnect();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      // 화면이 mounted 되었을 때만 업데이트 되게 함
      super.setState(fn);
    }
  }

  /* 연결 상태 갱신 */
  void setBleConnectionState(BluetoothDeviceState event) {
    switch (event) {
      case BluetoothDeviceState.disconnected:
        stateText = 'Disconnected';
        connectButtonText = 'Connect';
        break;
      case BluetoothDeviceState.disconnecting:
        stateText = 'Disconnecting';
        break;
      case BluetoothDeviceState.connected:
        stateText = 'Connected';
        connectButtonText = 'Disconnect';
        break;
      case BluetoothDeviceState.connecting:
        stateText = 'Connecting';
        break;
    }
    deviceState = event;
    setState(() {});
  }

  /* 연결 시작 */
  Future<bool> connect() async {
    setState(() {
      stateText = 'Connecting';
    });

    try {
      await widget.device.connect(autoConnect: false).timeout(Duration(seconds: 15));

      // 연결 성공 시 서비스 발견
      bluetoothService = await widget.device.discoverServices();

      for (var service in bluetoothService) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              setState(() {
                notifyDatas[characteristic.uuid.toString()] = value;
              });
            });
          }
        }
      }

      setBleConnectionState(BluetoothDeviceState.connected);
      return true;
    } catch (e) {
      setBleConnectionState(BluetoothDeviceState.disconnected);
      return false;
    }
  }

  /* 연결 해제 */
  void disconnect() {
    try {
      widget.device.disconnect();
      setState(() {
        stateText = 'Disconnected';
      });
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(stateText),
                OutlinedButton(
                  onPressed: () {
                    if (deviceState == BluetoothDeviceState.connected) {
                      disconnect();
                    } else if (deviceState == BluetoothDeviceState.disconnected) {
                      connect();
                    }
                  },
                  child: Text(connectButtonText),
                ),
              ],
            ),
            Expanded(
              child: ListView.separated(
                itemCount: bluetoothService.length,
                itemBuilder: (context, index) {
                  return listItem(bluetoothService[index]);
                },
                separatorBuilder: (BuildContext context, int index) {
                  return Divider();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* 각 캐릭터리스틱 정보 표시 위젯 */
  Widget characteristicInfo(BluetoothService service) {
    String info = '';
    for (var characteristic in service.characteristics) {
      String properties = '';
      if (characteristic.properties.write) properties += 'Write ';
      if (characteristic.properties.read) properties += 'Read ';
      if (characteristic.properties.notify) properties += 'Notify ';
      if (characteristic.properties.writeWithoutResponse) properties += 'WriteWithoutResponse ';
      if (characteristic.properties.indicate) properties += 'Indicate ';

      info += '${characteristic.uuid}\nProperties: $properties\n';
      if (notifyDatas[characteristic.uuid.toString()] != null) {
        info += 'Data: ${notifyDatas[characteristic.uuid.toString()]}\n';
      }
    }
    return Text(info);
  }

  /* Service UUID 위젯  */
  Widget serviceUUID(BluetoothService service) {
    return Text(service.uuid.toString());
  }

  /* Service 정보 아이템 위젯 */
  Widget listItem(BluetoothService service) {
    return ListTile(
      title: serviceUUID(service),
      subtitle: characteristicInfo(service),
    );
  }
}
