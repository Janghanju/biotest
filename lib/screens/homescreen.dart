import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:video_player/video_player.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/control_slider.dart';
import '../widgets/dataitem.dart';
import 'BluetoothDeviceManager.dart';
import 'Serial.dart';
import 'SettingsScreen.dart';
import 'login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  final String title;

  const HomeScreen({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic> _data = {};
  List<List<FlSpot>> tempSpots = List.generate(14, (_) => <FlSpot>[]);
  double rtRPM = 0.0;
  double setRPM = 0.0;
  double setRPM2 = 0.0;
  double rtRPM2 = 0.0;
  double rtTemp = 0.0;
  double rtTemp2 = 0.0;
  double setTemp = 0.0;
  double setTemp2 = 0.0;
  double phValue = 0.0;
  double userSetRPM = 0.0;
  double userSetRPM2 = 0.0;
  double userSetTemp = 0.0;
  double userSetTemp2 = 0.0;
  //PH, DO가 추가되어야함
  bool UV = false;
  bool LED = false;

  late VideoPlayerController _videoPlayerController;
  String? _fcmToken;

  String selectedTemp = 'RT_Temp';
  String? selectedDeviceId;
  String? selectedDeviceName;
  List<String> tempKeys = [
    'RT_Temp',
    'RT_RPM',
    'PH',
    'UV',
    'LED',
    'RT_Temp2',
    'RT_RPM2',
    'temp1',
    'temp2',
    'temp3',
    'temp4',
    'temp5',
    'temp6',
    'temp7'
  ];
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _motorRpmController = TextEditingController();
  final TextEditingController _temperatureController2 = TextEditingController();
  final TextEditingController _motorRpmController2 = TextEditingController();
  List<Map<String, String>> registeredDevices = [];

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _initializeVideoPlayer();
    loadRegisteredDevices();
  }

  Future<void> _initializeFirebase() async {
    _databaseReference = FirebaseDatabase.instance.ref();
    FirebaseMessaging.instance.getToken().then((token) {
      _fcmToken = token;
      print('FCM Token: $_fcmToken');
    });
    _initializeDataListeners();
  }

  void _initializeVideoPlayer() {
    _videoPlayerController = VideoPlayerController.network(
      "http://210.99.70.120:1935/live/cctv010.stream/playlist.m3u8",
    )
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      }).catchError((error) {
        print('Video Player Initialization Error: $error');
      });
  }

  void _initializeDataListeners() {
    _databaseReference.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _data = data.cast<String, dynamic>();
          _updateAllValues();
          _updateTempData();
        });
      }
    });
  }

  void loadRegisteredDevices() async {
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

      setState(() {
        registeredDevices = devices;
        if (registeredDevices.isNotEmpty) {
          selectedDeviceId = registeredDevices.first['uuid'];
          selectedDeviceName = registeredDevices.first['name'];
        }
      });
    }
  }

  void _updateAllValues() {
    rtRPM = double.tryParse(_data['RT_RPM']?.toString() ?? '0.0') ?? 0.0;
    setRPM = double.tryParse(_data['set_RPM']?.toString() ?? '0.0') ?? 0.0;
    setRPM2 = double.tryParse(_data['set_RPM2']?.toString() ?? '0.0') ?? 0.0;
    rtRPM2 = double.tryParse(_data['RT_RPM2']?.toString() ?? '0.0') ?? 0.0;
    rtTemp = double.tryParse(_data['RT_Temp']?.toString() ?? '0.0') ?? 0.0;
    setTemp = double.tryParse(_data['set_Temp']?.toString() ?? '0.0') ?? 0.0;
    rtTemp2 = double.tryParse(_data['RT_Temp2']?.toString() ?? '0.0') ?? 0.0;
    setTemp2 = double.tryParse(_data['set_Temp2']?.toString() ?? '0.0') ?? 0.0;
    phValue = double.tryParse(_data['PH']?.toString() ?? '0.0') ?? 0.0;
    UV = _data['UV'] ?? false;
    LED = _data['LED'] ?? false;

    _initializeTextControllers();
  }

  void _initializeTextControllers() {
    if (_motorRpmController.text.isEmpty) {
      _motorRpmController.text = setRPM.toStringAsFixed(1);
    }
    if (_motorRpmController2.text.isEmpty) {
      _motorRpmController2.text = setRPM2.toStringAsFixed(1);
    }
    if (_temperatureController.text.isEmpty) {
      _temperatureController.text = setTemp.toStringAsFixed(2);
    }
    if (_temperatureController2.text.isEmpty) {
      _temperatureController2.text = setTemp2.toStringAsFixed(2);
    }
  }

  void _updateTempData() {
    for (int i = 0; i < tempKeys.length; i++) {
      _updateTemp(tempKeys[i], tempSpots[i]);
    }
  }

  void _updateTemp(String key, List<FlSpot> spots) {
    if (_data.containsKey(key)) {
      double value = double.tryParse(_data[key].toString()) ?? 0.0;
      if (value >= -55 && value <= 125) {
        if (spots.length >= 60) {
          spots.removeAt(0);
        }
        spots.add(FlSpot(spots.length.toDouble(), value));
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _temperatureController.dispose();
    _motorRpmController.dispose();
    _temperatureController2.dispose();
    _motorRpmController2.dispose();
    FlutterBlue.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetGraph,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: registeredDevices.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildDeviceDropdown(),
          Expanded(
            child: Column(
              children: [
                _buildDeviceStatusCard(),
                _buildMainContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDropdown() {
    return DropdownButton<String>(
      value: selectedDeviceId,
      onChanged: (String? newDeviceId) {
        setState(() {
          selectedDeviceId = newDeviceId;
          selectedDeviceName = registeredDevices
              .firstWhere((device) => device['uuid'] == newDeviceId)['name'];
        });
        // 기기 변경 시 추가로 할 작업이 있으면 여기에 작성
      },
      items: registeredDevices.map<DropdownMenuItem<String>>((device) {
        return DropdownMenuItem<String>(
          value: device['uuid'],
          child: Text(device['name']!),
        );
      }).toList(),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Card(
      color: Colors.blueAccent,
      child: ListTile(
        title: Text('Selected Device: $selectedDeviceName'),
        subtitle: Text('UUID: $selectedDeviceId'),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.device_hub),
            title: Text('Device'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BluetoothDeviceRegistration()));
            },
          ),
          ListTile(
            leading: Icon(Icons.device_hub),
            title: Text('Serial'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BluetoothSerialCommunication()));
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              logout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: _videoPlayerController.value.isInitialized
                ? VideoPlayer(_videoPlayerController)
                : Center(child: CircularProgressIndicator()),
          ),
          _buildDataItems(),
          SizedBox(height: 20),
          _buildDropdown(),
          SizedBox(height: 20),
          _buildGraph(),
          SizedBox(height: 20),
          _buildControlSliders(),
          SizedBox(height: 20),
          _buildAdditionalControls(),
        ],
      ),
    );
  }

  Widget _buildDataItems() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: DataItem(data: _data, dataKey: 'RT_Temp')),
            Expanded(child: DataItem(data: _data, dataKey: 'RT_RPM')),
            Expanded(child: DataItem(data: _data, dataKey: 'PH')),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: DataItem(data: _data, dataKey: 'RT_Temp2')),
            Expanded(child: DataItem(data: _data, dataKey: 'RT_RPM2')),
            Expanded(child: DataItem(data: _data, dataKey: 'PH2')),
          ],
        ),
      ],
    );
  }

  Widget _buildControlSliders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              Text('RT RPM: ${rtRPM.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              ControlSlider(
                label: 'Set RPM: ${userSetRPM.toStringAsFixed(1)}',
                value: userSetRPM,
                min: 0,
                max: 3000,
                onChanged: (value) {
                  setState(() {
                    userSetRPM = value;
                    _motorRpmController.text = userSetRPM.toStringAsFixed(1);
                  });
                },
              ),
              TextField(
                controller: _motorRpmController,
                decoration: InputDecoration(
                  labelText: 'Set RPM Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  double? newValue = double.tryParse(value);
                  if (newValue != null && newValue >= 0 && newValue <= 3000) {
                    setState(() {
                      userSetRPM = newValue;
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setMotorRpm,
                child: Text('Set RPM'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('RT Temp: ${rtTemp.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              ControlSlider(
                label: 'Set Temp: ${userSetTemp.toStringAsFixed(2)}',
                value: userSetTemp,
                min: 0,
                max: 80,
                onChanged: (value) {
                  setState(() {
                    userSetTemp = value;
                    _temperatureController.text =
                        userSetTemp.toStringAsFixed(2);
                  });
                },
              ),
              TextField(
                controller: _temperatureController,
                decoration: InputDecoration(
                  labelText: 'Set Temp Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  double? newValue = double.tryParse(value);
                  if (newValue != null && newValue >= 0 && newValue <= 80) {
                    setState(() {
                      userSetTemp = newValue;
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setTargetTemperature,
                child: Text('Set Temp'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('UV Status: ${UV ? "On" : "Off"}',
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              ElevatedButton(
                onPressed: _toggleUV,
                child: Text(UV ? 'Set UV Off' : 'Set UV On'),
              ),
              Text('LED Status: ${LED ? "On" : "Off"}',
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              ElevatedButton(
                onPressed: _toggleLED,
                child: Text(LED ? 'Set LED Off' : 'Set LED On'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              Text('RT RPM2: ${rtRPM2.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              ControlSlider(
                label: 'Set RPM2: ${userSetRPM2.toStringAsFixed(1)}',
                value: userSetRPM2,
                min: 0,
                max: 3000,
                onChanged: (value) {
                  setState(() {
                    userSetRPM2 = value;
                    _motorRpmController2.text =
                        userSetRPM2.toStringAsFixed(1);
                  });
                },
              ),
              TextField(
                controller: _motorRpmController2,
                decoration: InputDecoration(
                  labelText: 'Set RPM2 Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  double? newValue2 = double.tryParse(value);
                  if (newValue2 != null && newValue2 >= 0 && newValue2 <= 3000) {
                    setState(() {
                      userSetRPM2 = newValue2;
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setMotorRpm2,
                child: Text('Set RPM2'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('RT Temp2: ${rtTemp2.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, color: Colors.black)),
              ControlSlider(
                label: 'Set Temp2: ${userSetTemp2.toStringAsFixed(2)}',
                value: userSetTemp2,
                min: 0,
                max: 80,
                onChanged: (value) {
                  setState(() {
                    userSetTemp2 = value;
                    _temperatureController2.text =
                        userSetTemp2.toStringAsFixed(2);
                  });
                },
              ),
              TextField(
                controller: _temperatureController2,
                decoration: InputDecoration(
                  labelText: 'Set Temp2 Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  double? newValue2 = double.tryParse(value);
                  if (newValue2 != null && newValue2 >= 0 && newValue2 <= 80) {
                    setState(() {
                      userSetTemp2 = newValue2;
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setTargetTemperature2,
                child: Text('Set Temp2'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: selectedTemp,
      onChanged: (String? newValue) {
        setState(() {
          selectedTemp = newValue!;
        });
      },
      items: tempKeys.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  Widget _buildGraph() {
    int selectedIndex = tempKeys.indexOf(selectedTemp);
    List<FlSpot> selectedSpots = tempSpots[selectedIndex];

    return Container(
      height: 400,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: selectedSpots.isEmpty ? [FlSpot(0, 0)] : selectedSpots,
              isCurved: true,
              color: Colors.blue,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  void _resetGraph() {
    setState(() {
      for (var spots in tempSpots) {
        spots.clear();
      }
    });
  }

  void _toggleUV() {
    setState(() {
      UV = !UV;
      _databaseReference.child('UV').set(UV);
    });
  }

  void _toggleLED() {
    setState(() {
      LED = !LED;
      _databaseReference.child('LED').set(LED);
    });
  }

  void _setTargetTemperature() {
    double newTemp = double.tryParse(_temperatureController.text) ?? 0.0;
    if (newTemp >= 0 && newTemp <= 80) {
      setState(() {
        userSetTemp = newTemp;
        _databaseReference.child('set_Temp').set(userSetTemp);
      });
    } else {
      _showInvalidInputSnackbar(
          'Please enter a valid temperature between 0 and 80.');
    }
  }

  void _setTargetTemperature2() {
    double newTemp2 = double.tryParse(_temperatureController2.text) ?? 0.0;
    if (newTemp2 >= 0 && newTemp2 <= 80) {
      setState(() {
        userSetTemp2 = newTemp2;
        _databaseReference.child('set_Temp2').set(userSetTemp2);
      });
    } else {
      _showInvalidInputSnackbar(
          'Please enter a valid temperature between 0 and 80.');
    }
  }

  void _setMotorRpm() {
    double newRpm = double.tryParse(_motorRpmController.text) ?? 0.0;
    if (newRpm >= 0 && newRpm <= 3000) {
      setState(() {
        userSetRPM = newRpm;
        _databaseReference.child('set_RPM').set(userSetRPM);
      });
    } else {
      _showInvalidInputSnackbar('Please enter a valid RPM between 0 and 3000.');
    }
  }

  void _setMotorRpm2() {
    double newRpm2 = double.tryParse(_motorRpmController2.text) ?? 0.0;
    if (newRpm2 >= 0 && newRpm2 <= 3000) {
      setState(() {
        userSetRPM2 = newRpm2;
        _databaseReference.child('set_RPM2').set(userSetRPM2);
      });
    } else {
      _showInvalidInputSnackbar('Please enter a valid RPM between 0 and 3000.');
    }
  }

  void _showInvalidInputSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      print("Logout error :$e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('로그아웃 실패')));
    }
  }
}

enum DeviceStatus { online, offline }
