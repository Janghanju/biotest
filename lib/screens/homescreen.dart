import 'package:biotest/screens/getItem.dart';
import 'package:biotest/screens/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/notification.dart';
import '../widgets/dataitem.dart';
import '../widgets/control_slider.dart';

class HomeScreen extends StatefulWidget {
  final String title;

  const HomeScreen({Key? key, required this.title}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic> _data = {};
  List<List<FlSpot>> tempSpots = List.generate(12, (_) => <FlSpot>[]); // 각 온도 데이터 리스트 생성
  double motorRpm = 0.0;
  double targetTemperature = 0.0;
  double setTemperature = 0.0;
  bool uvIsOn = false;
  bool ledIsOn = false;

  late VideoPlayerController _videoPlayerController;
  String? _fcmToken;

  String selectedTemp = 'temp1';
  final List<String> tempKeys = [
    'temp1', 'temp2', 'temp3', 'temp4', 'temp5', 'temp6',
    'temp7', 'temp8', 'temp9', 'temp10', 'temp11', 'temp12'
  ];
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _motorRpmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref();

    // 초기 값 파이어베이스에서 가져오기
    _databaseReference.child('RT_RPM').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null) {
        setState(() {
          motorRpm = double.tryParse(value.toString()) ?? 0.0;
          _motorRpmController.text = motorRpm.toStringAsFixed(1);
        });
      }
    });

    _databaseReference.child('RT_Temp').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null) {
        setState(() {
          setTemperature = double.tryParse(value.toString()) ?? 0.0;
          _temperatureController.text = setTemperature.toStringAsFixed(2);
        });
      }
    });

    _databaseReference.child('set_temp').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null) {
        setState(() {
          targetTemperature = double.tryParse(value.toString()) ?? 0.0;
          _temperatureController.text = targetTemperature.toStringAsFixed(2);
        });
      }
    });

    _databaseReference.child('uvIsOn').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null) {
        setState(() {
          uvIsOn = value as bool;
        });
      }
    });

    _databaseReference.child('ledIsOn').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null) {
        setState(() {
          ledIsOn = value as bool;
        });
      }
    });

    _databaseReference.onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        if (value != null) {
          _data = value.cast<String, dynamic>();
          _updateTempData();
          _updateControlValues();
          _checkTemperatureAndSendMessage();
        } else {
          _data = {};
        }
      });
    });

    // RTSP 스트림 URL로 비디오 플레이어 초기화
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse("http://210.99.70.120:1935/live/cctv010.stream/playlist.m3u8"))
      ..initialize().then((_) {
        setState(() {});
        _videoPlayerController.play();
      }).catchError((error) {
        print('Video Player Initialization Error: $error');
      });
  }

  Future<void> _getFcmToken() async {
    _fcmToken = await FirebaseService.getFcmToken();
    debugPrint("FCM:$_fcmToken");
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _temperatureController.dispose();
    _motorRpmController.dispose();
    super.dispose();
  }

  void _updateTempData() {
    for (int i = 0; i < tempKeys.length; i++) {
      _updateTemp(tempKeys[i], tempSpots[i]);
    }
  }

  void _updateTemp(String key, List<FlSpot> spots) {
    if (_data.containsKey(key)) {
      double value = double.tryParse(_data[key].toString()) ?? 0.0;
      if (value >= -55 && value <= 125) { // 온도 범위 체크
        if (spots.length >= 60) {
          spots.removeAt(0);
        }
        spots.add(FlSpot(spots.length.toDouble(), value));
      }
    }
  }

  void _updateControlValues() {
    if (_data.containsKey('RT_RPM')) {
      motorRpm = double.tryParse(_data['RT_RPM'].toString()) ?? 0.0;
      _motorRpmController.text = motorRpm.toStringAsFixed(1);
    }
    if (_data.containsKey('set_temp')) {
      double newTemp = double.tryParse(_data['set_temp'].toString()) ?? 0.0;
      if (newTemp >= -55 && newTemp <= 125) { // 온도 범위 체크
        targetTemperature = newTemp;
        _temperatureController.text = targetTemperature.toStringAsFixed(2);
      }
    }
    if (_data.containsKey('uvIsOn')) {
      uvIsOn = _data['uvIsOn'] == true;
    }
    if (_data.containsKey('ledIsOn')) {
      ledIsOn = _data['ledIsOn'] == true;
    }
  }

  void _checkTemperatureAndSendMessage() {
    if (_data['temp1'] >= 100) {
      NotificationService.sendNotification(
        'Temperature Alert',
        'The temperature has reached or exceeded $targetTemperature°C.',
      );
    }
  }

  void _resetGraph() {
    setState(() {
      for (int i = 0; i < tempSpots.length; i++) {
        tempSpots[i].clear();
      }
    });
  }

  void _toggleUV() {
    setState(() {
      uvIsOn = !uvIsOn;
      _databaseReference.child('uvIsOn').set(uvIsOn);
    });
  }

  void _toggleLED() {
    setState(() {
      ledIsOn = !ledIsOn;
      _databaseReference.child('ledIsOn').set(ledIsOn);
    });
  }

  void _setTargetTemperature() {
    double newTemp = double.tryParse(_temperatureController.text) ?? 0.0;
    if (newTemp >= 0 && newTemp <= 80) { // Set Temp 범위 체크
      setState(() {
        targetTemperature = newTemp;
        _databaseReference.child('set_temp').set(targetTemperature);
        _temperatureController.text = targetTemperature.toStringAsFixed(2);
      });
    } else {
      // 잘못된 범위 값 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid temperature between 0 and 80.')),
      );
    }
  }

  void _setMotorRpm() {
    double newRpm = double.tryParse(_motorRpmController.text) ?? 0.0;
    if (newRpm >= 0 && newRpm <= 3000) {
      setState(() {
        motorRpm = newRpm;
        _databaseReference.child('RT_RPM').set(motorRpm);
        _motorRpmController.text = motorRpm.toStringAsFixed(1);
      });
    } else {
      // 잘못된 범위 값 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid RPM between 0 and 3000.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _resetGraph();
              setState(() {
                _databaseReference = FirebaseDatabase.instance.ref();
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.device_hub),
              title: Text('Device'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DeviceAddPage()),
                );
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
      ),
      body: Container(
        color: Colors.grey[200],
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: _videoPlayerController.value.isInitialized
                    ? VideoPlayer(_videoPlayerController)
                    : Center(child: CircularProgressIndicator()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: DataItem(
                        data: _data,
                        dataKey: 'temp1',
                        icon: Icon(Icons.thermostat, color: Colors.red),
                      ),
                    ),
                    Expanded(
                      child: DataItem(
                        data: _data,
                        dataKey: 'temp2',
                        icon: Icon(Icons.thermostat, color: Colors.orange),
                      ),
                    ),
                    Expanded(
                      child: DataItem(
                        data: _data,
                        dataKey: 'temp3',
                        icon: Icon(Icons.thermostat, color: Colors.yellow),
                      ),
                    ),

                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildDropdown(),
              SizedBox(height: 20),
              _buildGraph(),
              SizedBox(height: 20),
              _buildControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Select Temperature Data:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          DropdownButton<String>(
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
          ),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    int selectedIndex = tempKeys.indexOf(selectedTemp);
    List<FlSpot> selectedSpots = tempSpots[selectedIndex];

    return Container(
      height: 400,
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedTemp == 'temp1' ? 'Daily Temperature Chart' : 'Weekly Temperature Chart',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}°C'),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}h'),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: selectedSpots.isEmpty ? [FlSpot(0, 0)] : selectedSpots,
                    isCurved: true,
                    color: Colors.red,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.3)),
                  ),
                ],
                minY: 60,
                maxY: 200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildMotorControl(),
                SizedBox(height: 20),
                _buildTemperatureControl(),
              ],
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _buildToggleControl('UV Light', uvIsOn, _toggleUV, Icons.lightbulb_outline),
                SizedBox(height: 20),
                _buildToggleControl('LED Light', ledIsOn, _toggleLED, Icons.lightbulb_outline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotorControl() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motor RPM Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
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
                  motorRpm = newValue;
                  _databaseReference.child('RT_RPM').set(motorRpm);
                });
              }
            },
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: _setMotorRpm,
            child: Text('Set RPM'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureControl() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Temperature Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
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
                  targetTemperature = newValue;
                  _databaseReference.child('set_temp').set(targetTemperature);
                });
              }
            },
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: _setTargetTemperature,
            child: Text('Set Temp'),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleControl(String label, bool isOn, VoidCallback toggleFunction, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status: ${isOn ? "On" : "Off"}', style: TextStyle(fontSize: 16)),
              IconButton(
                icon: Icon(icon, color: isOn ? Colors.green : Colors.grey),
                onPressed: toggleFunction,
              ),
            ],
          ),
          ElevatedButton(
            onPressed: toggleFunction,
            child: Text(isOn ? 'Turn Off' : 'Turn On'),
          ),
        ],
      ),
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
      print("로그아웃 에러 :$e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그아웃 실패')),
      );
    }
  }
}

