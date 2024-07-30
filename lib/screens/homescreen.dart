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
  final String cameraStreamUrl;

  const HomeScreen({
    Key? key,
    required this.title,
    required this.cameraStreamUrl,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic> _data = {};
  List<FlSpot> tempSpots = List.generate(12, (_) => []);
  double motorRpm = 0.0;
  double targetTemperature = 0.0;
  bool uvIsOn = false;

  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  String? _fcmToken;

  String selectedTemp = 'temp1';

  get tempKeys => null;  // 기본값

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
    _videoPlayerController = VideoPlayerController.network(widget.cameraStreamUrl)
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
    if (tempKeys.contains(selectedTemp)) {
      _updateTemp(selectedTemp, _getSpotsForKey(selectedTemp) as List<FlSpot>);
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

  FlSpot _getSpotsForKey(String key) {
    final index = int.tryParse(key.replaceAll('temp', '')) ?? 1;
    return tempSpots[index - 1];
  }

  void _updateControlValues() {
    motorRpm = _data.containsKey('motorRpm') ? double.tryParse(_data['motorRpm'].toString()) ?? 0.0 : motorRpm;
    targetTemperature = _data.containsKey('targetTemperature') ? double.tryParse(_data['targetTemperature'].toString()) ?? 0.0 : targetTemperature;
    uvIsOn = _data.containsKey('uvIsOn') ? _data['uvIsOn'] == true : uvIsOn;
  }

  void _checkTemperatureAndSendMessage() {
    if (targetTemperature >= 65.0) {
      NotificationService.sendNotification(
        'Temperature Alert',
        'The temperature has reached or exceeded $targetTemperature°C.',
      );
    }
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
              // 드롭다운 버튼 추가
              DropdownButton<String>(
                value: selectedTemp,
                items: tempKeys.map((String key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(key),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedTemp = newValue!;
                    _updateTempData(); // 데이터 업데이트
                  });
                },
              ),
              // Row를 SingleChildScrollView로 감싸서 스크롤 가능하도록 수정
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ...tempKeys.map((key) => DataItem(data: _data, dataKey: key)),
                  ],
                ),
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
                  _buildControlColumn(
                    label: 'Motor RPM',
                    value: motorRpm,
                    min: 0,
                    max: 3000,
                    onValueChanged: (value) => setState(() => motorRpm = value),
                    onSubmit: () => _databaseReference.child('motorRpm').set(motorRpm),
                  ),
                  _buildControlColumn(
                    label: 'Target Temperature',
                    value: targetTemperature,
                    min: 0,
                    max: 65.99,
                    onValueChanged: (value) => setState(() => targetTemperature = value),
                    onSubmit: () => _databaseReference.child('targetTemperature').set(targetTemperature),
                  ),
                  _buildControlColumn(
                    label: 'UV Status',
                    value: uvIsOn ? "On" : "Off",
                    onSubmit: _toggleUV,
                    buttonText: uvIsOn ? 'Turn UV Off' : 'Turn UV On',
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



