import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_chart/fl_chart.dart';
import 'firebase_options.dart'; // Ensure you have your Firebase configuration file
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(MyApp());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('FirebaseApp with name [DEFAULT] already exists')) {
      print('Firebase already initialized');
    } else {
      rethrow;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bio_reactor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Bio-reactor Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
  String? _fcmToken; // FCM 토큰을 저장할 변수

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
          _checkTemperatureAndSendMessage(); // Check temperature and send message
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
      // You can navigate to a specific screen or update the UI here
    });

    // Get the FCM token
    _getFcmToken();
  }

  Future<void> _getFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      setState(() {
        _fcmToken = fcmToken;
      });
      print('FCM Token: $_fcmToken');
    } catch (e) {
      print('Failed to get FCM token: $e');
    }
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
    if (targetTemperature >= 65.0) { // Example condition
      sendNotification(
        'Temperature Alert',
        'The temperature has reached or exceeded $targetTemperature°C.',
      );
    }
  }

  Future<void> sendNotification(String title, String body) async {
    const String serverKey = 'YOUR_SERVER_KEY'; // Replace with your FCM server key
    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: json.encode({
        'notification': {
          'title': title,
          'body': body,
        },
        'priority': 'high',
        'to': '/topics/temperature',
      }),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification');
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
              _buildStreamingView(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDataItem('temp1'),
                  _buildDataItem('temp2'),
                  _buildDataItem('temp3'),
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
                      _buildSlider('Motor RPM', motorRpm, 0, 3000, (value) {
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
                      _buildSlider('Target Temperature', targetTemperature, 0, 65.99, (value) {
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

  Widget _buildStreamingView() {
    if (_chewieController == null) {
      return Center(child: CircularProgressIndicator());
    } else {
      return Container(
        height: 200,
        child: Chewie(controller: _chewieController!),
      );
    }
  }

  Widget _buildDataItem(String key) {
    return Column(
      children: [
        Text(
          '${key.toUpperCase()}: ${_data[key] ?? 'N/A'}',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      ],
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

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
