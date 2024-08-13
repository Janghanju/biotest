import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'BluetoothDeviceManager.dart';

// A widget to handle Bluetooth device registration
class BluetoothDeviceRegistration extends StatefulWidget {
  final BluetoothDeviceManager deviceManager;

  const BluetoothDeviceRegistration({Key? key, required this.deviceManager}) : super(key: key);

  @override
  _BluetoothDeviceRegistrationState createState() => _BluetoothDeviceRegistrationState();
}

class _BluetoothDeviceRegistrationState extends State<BluetoothDeviceRegistration> {
  List<BluetoothDevice> devices = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() {
      isScanning = true;
    });

    FlutterBlue.instance.startScan(timeout: Duration(seconds: 5)).then((_) {
      setState(() {
        isScanning = false;
      });
    });

    FlutterBlue.instance.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!devices.contains(result.device)) {
          setState(() {
            devices.add(result.device);
          });
        }
      }
    });
  }

  void _registerDevice(BluetoothDevice device) {
    widget.deviceManager.connectToDevice(device);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register Bluetooth Device'),
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: isScanning ? null : _startScan,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          BluetoothDevice device = devices[index];
          return ListTile(
            title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
            subtitle: Text(device.id.toString()),
            trailing: IconButton(
              icon: Icon(Icons.add),
              onPressed: () => _registerDevice(device),
            ),
          );
        },
      ),
    );
  }
}
