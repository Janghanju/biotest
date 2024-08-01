import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceAddPage extends StatefulWidget {
  @override
  _DeviceAddPageState createState() => _DeviceAddPageState();
}

class _DeviceAddPageState extends State<DeviceAddPage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> devicesList = [];
  bool _canVibrate = true;
  bool _scanning = false;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    bool canVibrate = await Vibrate.canVibrate;
    setState(() {
      _canVibrate = canVibrate;
    });
    _scanForDevices();
  }

  void _scanForDevices() {
    setState(() {
      _scanning = true;
      devicesList.clear();
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5));

    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!devicesList.contains(r.device)) {
          setState(() {
            devicesList.add(r.device);
          });
        }
      }
    }).onDone(() {
      setState(() {
        _scanning = false;
      });
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      FlutterBeep.beep();
      if (_canVibrate) Vibrate.feedback(FeedbackType.heavy);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DeviceDetailsPage(device: device, onRegister: _registerDevice),
        ),
      );
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  void _registerDevice(BluetoothDevice device) async {
    // 기기 정보 및 데이터를 Firebase Realtime Database로 전송
    final String deviceId = device.id.toString();
    final String deviceName = device.name.isNotEmpty ? device.name : 'Unknown Device';

    await _database.child('devices').child(deviceId).set({
      'name': deviceName,
      'status': 'registered',
      'timestamp': DateTime.now().toIso8601String(),
    });

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('기기 등록'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                final device = devicesList[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                  subtitle: Text(device.id.toString()),
                  trailing: IconButton(
                    icon: Icon(Icons.connect_without_contact),
                    onPressed: () => _connectToDevice(device),
                  ),
                );
              },
            ),
          ),
          if (_scanning) CircularProgressIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanForDevices,
        tooltip: 'Scan for Devices',
        child: Icon(Icons.refresh),
      ),
    );
  }
}

class DeviceDetailsPage extends StatefulWidget {
  final BluetoothDevice device;
  final Function(BluetoothDevice) onRegister;

  DeviceDetailsPage({Key? key, required this.device, required this.onRegister}) : super(key: key);

  @override
  _DeviceDetailsPageState createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  @override
  void initState() {
    super.initState();
    // 기기 등록
    widget.onRegister(widget.device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('기기 등록 완료'),
      ),
      body: Center(
        child: Text('기기 ${widget.device.name} 등록 완료'),
      ),
    );
  }
}

