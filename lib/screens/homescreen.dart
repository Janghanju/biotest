import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
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
  bool uvIsOn = false;

  late VideoPlayerController _videoPlayerController;
  String? _fcmToken;

  String selectedTemp = 'temp1';
  final List<String> tempKeys = [
    'temp1', 'temp2', 'temp3', 'temp4', 'temp5', 'temp6',
    'temp7', 'temp8', 'temp9', 'temp10', 'temp11', 'temp12'
  ];
  final TextEditingController _temperatureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref();
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

    // Initialize video player with the RTSP stream URL
    print("Url Success");
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse("http://210.99.70.120:1935/live/cctv010.stream/playlist.m3u8"))
      ..initialize().then((_) {
        setState(() {});
        print("videovideo");
        _videoPlayerController.play();
        print("Video1");
      }).catchError((error) {
        print('Video Player Initialization Error: $error');
      });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Message received: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened: ${message.notification?.title}');
    });

    _getFcmToken();
  }

  Future<void> _getFcmToken() async {
    _fcmToken = await FirebaseService.getFcmToken();
    debugPrint("FCM:$_fcmToken");
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _temperatureController.dispose();
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
      if (spots.length >= 60) {
        spots.removeAt(0);
      }
      spots.add(FlSpot(spots.length.toDouble(), value));
    }
  }

  void _updateControlValues() {
    if (_data.containsKey('motorRpm')) {
      motorRpm = double.tryParse(_data['motorRpm'].toString()) ?? 0.0;
    }
    if (_data.containsKey('temp1')) {
      double newTemp = double.tryParse(_data['temp1'].toString()) ?? 0.0;
      if (newTemp >= 0 && newTemp <= 30) {
        targetTemperature = newTemp;
      }
    }
    if (_data.containsKey('uvIsOn')) {
      uvIsOn = _data['uvIsOn'] == true;
    }
  }

  void _checkTemperatureAndSendMessage() {
    if (_data['temp1'] >= 30) {
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

  void _setTargetTemperature() {
    double newTemp = double.tryParse(_temperatureController.text) ?? 0.0;
    if (newTemp >= 0 && newTemp <= 30) {
      setState(() {
        targetTemperature = newTemp;
        _databaseReference.child('targetTemperature').set(targetTemperature);
      });
    } else {
      // Show an error message or handle the out-of-range value appropriately
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid temperature between 0 and 30.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.lightBlue,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: DataItem(data: _data, dataKey: 'temp1')),
                  Expanded(child: DataItem(data: _data, dataKey: 'temp2')),
                  Expanded(child: DataItem(data: _data, dataKey: 'temp3')),
                ],
              ),
              SizedBox(height: 20),
              _buildDropdown(),
              SizedBox(height: 20),
              _buildGraph(),
              SizedBox(height: 20),
              Text(
                'FCM Token: ${_fcmToken ?? 'Loading...'}',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('Motor RPM: ${motorRpm.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ControlSlider(
                          label: 'Motor RPM',
                          value: motorRpm,
                          min: 0,
                          max: 3000,
                          onChanged: (value) {
                            setState(() {
                              motorRpm = value;
                            });
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _databaseReference.child('motorRpm').set(motorRpm);
                          },
                          child: Text('Set Motor RPM'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Target Temperature: ${targetTemperature.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ControlSlider(
                          label: 'Target Temperature',
                          value: targetTemperature,
                          min: 0,
                          max: 30,
                          onChanged: (value) {
                            setState(() {
                              targetTemperature = value;
                            });
                          },
                        ),
                        TextField(
                          controller: _temperatureController,
                          decoration: InputDecoration(
                            labelText: 'Set Target Temperature',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        ElevatedButton(
                          onPressed: _setTargetTemperature,
                          child: Text('Set Target Temperature'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('UV Status: ${uvIsOn ? "On" : "Off"}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ElevatedButton(
                          onPressed: _toggleUV,
                          child: Text(uvIsOn ? 'Turn UV Off' : 'Turn UV On'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                color: Colors.lightBlue[50],
                height: 100,
              ),
            ],
          ),
        ),
      ),
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
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: selectedSpots.isEmpty ? [FlSpot(0, 0)] : selectedSpots,
              isCurved: true,
              color: Colors.red,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
