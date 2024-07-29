import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/notification.dart';
import '../widgets/streaming_view.dart';
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
  List<FlSpot> temp1Spots = [];
  List<FlSpot> temp2Spots = [];
  List<FlSpot> temp3Spots = [];
  double motorRpm = 0.0;
  double targetTemperature = 0.0;
  bool uvIsOn = false;

  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  String? _fcmToken;

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
    String cameraStreamUrl = 'rtsp://your_camera_stream_url';
    _videoPlayerController = VideoPlayerController.network(cameraStreamUrl)
      ..initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            aspectRatio: _videoPlayerController.value.aspectRatio,
            autoPlay: true,
            looping: true,
          );
        });
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
    print('FCM Token: $_fcmToken');
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _updateTempData() {
    _updateTemp('temp/temp1', temp1Spots);
    _updateTemp('temp/temp2', temp2Spots);
    _updateTemp('temp/temp3', temp3Spots);
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
    if (_data.containsKey('targetTemperature')) {
      targetTemperature = double.tryParse(_data['targetTemperature'].toString()) ?? 0.0;
    }
    if (_data.containsKey('uvIsOn')) {
      uvIsOn = _data['uvIsOn'] == true;
    }
  }

  void _checkTemperatureAndSendMessage() {
    if (targetTemperature >= 65.0) {
      NotificationService.sendNotification(
        'Temperature Alert',
        'The temperature has reached or exceeded $targetTemperature°C.',
      );
    }
  }

  void _resetGraph() {
    setState(() {
      temp1Spots.clear();
      temp2Spots.clear();
      temp3Spots.clear();
    });
  }

  void _toggleUV() {
    setState(() {
      uvIsOn = !uvIsOn;
      _databaseReference.child('uvIsOn').set(uvIsOn);
    });
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
              StreamingView(chewieController: _chewieController),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DataItem(data: _data, dataKey: 'temp1'),
                  DataItem(data: _data, dataKey: 'temp2'),
                  DataItem(data: _data, dataKey: 'temp3'),
                ],
              ),
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
                  Column(
                    children: [
                      Text('Motor RPM: ${motorRpm.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                      ControlSlider(label: 'Motor RPM', value: motorRpm, min: 0, max: 3000, onChanged: (value) {
                        setState(() {
                          motorRpm = value;
                        });
                      }),
                      ElevatedButton(
                        onPressed: () {
                          _databaseReference.child('motorRpm').set(motorRpm);
                        },
                        child: Text('Set Motor RPM'),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Target Temperature: ${targetTemperature.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                      ControlSlider(label: 'Target Temperature', value: targetTemperature, min: 0, max: 65.99, onChanged: (value) {
                        setState(() {
                          targetTemperature = value;
                        });
                      }),
                      ElevatedButton(
                        onPressed: () {
                          _databaseReference.child('targetTemperature').set(targetTemperature);
                        },
                        child: Text('Set Target Temperature'),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('UV Status: ${uvIsOn ? "On" : "Off"}', style: TextStyle(fontSize: 16, color: Colors.black)),
                      ElevatedButton(
                        onPressed: _toggleUV,
                        child: Text(uvIsOn ? 'Turn UV Off' : 'Turn UV On'),
                      ),
                    ],
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

  Widget _buildGraph() {
    return Container(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: temp1Spots,
              isCurved: true,
              color: Colors.red,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              spots: temp2Spots,
              isCurved: true,
              color: Colors.green,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              spots: temp3Spots,
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
}
