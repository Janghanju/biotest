import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  String stateText = 'Connecting';
  String connectButtonText = 'Disconnect';
  BluetoothConnectionState deviceState = BluetoothConnectionState.disconnected;
  StreamSubscription<BluetoothConnectionState>? _stateListener;
  List<BluetoothService> bluetoothService = [];
  Map<String, List<int>> notifyDatas = {};
  BluetoothCharacteristic? serialCharacteristic;
  List<String> logMessages = [];

  @override
  void initState() {
    super.initState();
    _stateListener = widget.device.state.listen((event) {
      setBleConnectionState(event as BluetoothConnectionState);
    }) as StreamSubscription<BluetoothConnectionState>?;
    connect();
  }

  @override
  void dispose() {
    _stateListener?.cancel();
    disconnect();
    super.dispose();
  }

  void setBleConnectionState(BluetoothConnectionState event) {
    setState(() {
      deviceState = event;
      switch (event) {
        case BluetoothConnectionState.disconnected:
          stateText = 'Disconnected';
          connectButtonText = 'Connect';
          break;
        case BluetoothConnectionState.connected:
          stateText = 'Connected';
          connectButtonText = 'Disconnect';
          break;
        case BluetoothConnectionState.connecting:
          stateText = 'Connecting';
          break;
        case BluetoothConnectionState.disconnecting:
          stateText = 'Disconnecting';
          break;
      }
    });
  }

  Future<bool> connect() async {
    try {
      await widget.device.connect(autoConnect: false);
      List<BluetoothService> bleServices = await widget.device.discoverServices();
      setState(() {
        bluetoothService = bleServices;
      });

      for (BluetoothService service in bleServices) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.properties.notify && c.descriptors.isNotEmpty) {
            if (!c.isNotifying) {
              await c.setNotifyValue(true);
              notifyDatas[c.uuid.toString()] = [];
              c.value.listen((value) {
                setState(() {
                  notifyDatas[c.uuid.toString()] = value;
                });
              });
            }
          }

          if (c.uuid.toString() == "0000ffe1-0000-1000-8000-00805f9b34fb") {
            serialCharacteristic = c;
            startListening(); // 시리얼 모니터 시작
          }
        }
      }

      // 연결 성공 시 토스트 메시지 표시
      Fluttertoast.showToast(msg: "Device connected successfully");
      return true;
    } catch (e) {
      setBleConnectionState(BluetoothConnectionState.disconnected);

      // 연결 실패 시 토스트 메시지 표시
      Fluttertoast.showToast(msg: "Failed to connect to device: $e");
      return false;
    }
  }

  void disconnect() {
    try {
      widget.device.disconnect();
      Fluttertoast.showToast(msg: "Device disconnected");
    } catch (e) {
      print("Disconnect error: $e");
      Fluttertoast.showToast(msg: "Error disconnecting device: $e");
    }
  }

  Future<void> sendData(String data) async {
    if (serialCharacteristic != null) {
      await serialCharacteristic!.write(utf8.encode(data));
      setState(() {
        logMessages.add("Sent: $data");
      });
    }
  }

  void startListening() {
    if (serialCharacteristic != null) {
      serialCharacteristic!.value.listen((value) {
        setState(() {
          logMessages.add("Received: ${utf8.decode(value)}");
        });
      });
      serialCharacteristic!.setNotifyValue(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('$stateText'),
              OutlinedButton(
                onPressed: () {
                  if (deviceState == BluetoothDeviceState.connected) {
                    disconnect();
                  } else if (deviceState ==
                      BluetoothDeviceState.disconnected) {
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
          Expanded(
            child: ListView.builder(
              itemCount: logMessages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(logMessages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onSubmitted: (text) {
                sendData(text);
              },
              decoration: InputDecoration(
                labelText: 'Enter message',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget characteristicInfo(BluetoothService r) {
    String name = '';
    String properties = '';
    String data = '';

    for (BluetoothCharacteristic c in r.characteristics) {
      properties = '';
      data = '';
      name += '\t\t${c.uuid}\n';
      if (c.properties.write) {
        properties += 'Write ';
      }
      if (c.properties.read) {
        properties += 'Read ';
      }
      if (c.properties.notify) {
        properties += 'Notify ';
        if (notifyDatas.containsKey(c.uuid.toString())) {
          if (notifyDatas[c.uuid.toString()]!.isNotEmpty) {
            data = notifyDatas[c.uuid.toString()].toString();
          }
        }
      }
      if (c.properties.writeWithoutResponse) {
        properties += 'WriteWR ';
      }
      if (c.properties.indicate) {
        properties += 'Indicate ';
      }
      name += '\t\t\tProperties: $properties\n';
      if (data.isNotEmpty) {
        name += '\t\t\t\t$data\n';
      }
    }
    return Text(name);
  }

  Widget serviceUUID(BluetoothService r) {
    return Text(r.uuid.toString());
  }

  Widget listItem(BluetoothService r) {
    return ListTile(
      onTap: null,
      title: serviceUUID(r),
      subtitle: characteristicInfo(r),
    );
  }
}

class BluetoothSerialCommunication extends StatefulWidget {
  @override
  _BluetoothSerialCommunicationState createState() =>
      _BluetoothSerialCommunicationState();
}

class _BluetoothSerialCommunicationState
    extends State<BluetoothSerialCommunication> {
  BluetoothDevice? connectedDevice;
  List<Map<String, String>> registeredDevices = [];
  String? selectedDeviceUUID;
  String? selectedDeviceName;
  List<String> logMessages = [];
  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void initState() {
    super.initState();
    loadRegisteredDevices();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> loadRegisteredDevices() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .get();

      List<Map<String, String>> devices = [];
      for (var doc in snapshot.docs) {
        devices.add({
          'uuid': doc['uuid'],
          'name': doc['name'],
        });
      }

      if (mounted) {
        setState(() {
          registeredDevices = devices;
          if (devices.isNotEmpty) {
            selectedDeviceUUID = devices.first['uuid'];
            selectedDeviceName = devices.first['name'];
          }
        });
      }
    }
  }

  Future<void> connectToDevice() async {
    if (selectedDeviceUUID != null) {
      scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();
      try {
        bool deviceFound = false;
        await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));

        scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
          for (ScanResult r in results) {
            print("Scanned Device: ${r.device.id.toString()}");

            // 선택한 UUID와 스캔된 기기 UUID가 일치하는지 확인
            if (r.device.id.toString() == selectedDeviceUUID) {
              deviceFound = true;
              try {
                await r.device.connect();
                setState(() {
                  connectedDevice = r.device;
                });
                await FlutterBluePlus.stopScan();

                // 연결 성공 시 시리얼 모니터 화면으로 전환
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(device: connectedDevice!),
                  ),
                );

                Fluttertoast.showToast(msg: "Device connected successfully");
                break;
              } catch (e) {
                setState(() {
                  logMessages.add("Connection error: $e");
                });
                Fluttertoast.showToast(msg: "Failed to connect to device");
              }
            }
          }
        });

        // 스캔이 완료된 후 기기를 찾지 못한 경우에 대한 처리
        scanSubscription?.onDone(() {
          if (!deviceFound) {
            Fluttertoast.showToast(msg: "Device not found");
          }
        });

      } catch (e) {
        setState(() {
          logMessages.add("Scan start error: $e");
        });
        Fluttertoast.showToast(msg: "Failed to start scan");
      }
    } else {
      Fluttertoast.showToast(msg: "No device selected");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("블루투스 기기 선택"),
      ),
      body: connectedDevice == null
          ? buildDeviceSelectionView()
          : Container(), // 기기 연결이 되어 있다면 빈 화면을 표시
    );
  }

  // 기기 선택 화면을 빌드하는 위젯
  Widget buildDeviceSelectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: selectedDeviceUUID,
            onChanged: (String? newUUID) {
              if (mounted) {
                setState(() {
                  selectedDeviceUUID = newUUID;
                  selectedDeviceName = registeredDevices
                      .firstWhere((device) => device['uuid'] == newUUID)['name'];
                });
              }
            },
            items: registeredDevices.map<DropdownMenuItem<String>>((device) {
              return DropdownMenuItem<String>(
                value: device['uuid'],
                child: Text('${device['uuid']}'),
              );
            }).toList(),
          ),
          ElevatedButton(
            onPressed: () {
              connectToDevice();
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }
}
