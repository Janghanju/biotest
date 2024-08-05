import 'dart:developer';

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
  double rtRPM = 0; // RT RPM 값
  double setRPM = 0.0; // Set RPM 값
  double rtTemp = 0.0; // RT Temp 값
  double setTemp = 0.0; // Set Temp 값
  bool UV = false; // UV 상태
  bool LED = false; // LED 상태

  late VideoPlayerController _videoPlayerController;
  String? _fcmToken;

  String selectedTemp = 'RT_Temp';
  final List<String> tempKeys = [
    'RT_Temp', 'RT_RPM', 'PH', 'UV', 'LED', 'temp6',
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
      final value1 = event.snapshot.value;
      if (value1 != null) {
        setState(() {
          rtRPM = double.tryParse(value1.toString()) ?? 0.0;
          _motorRpmController.text = rtRPM.toStringAsFixed(1);
        });
      }
    });

    _databaseReference.child('set_RPM').onValue.listen((event) {
      final value2 = event.snapshot.value;
      if (value2 != null) {
        setState(() {
          setRPM = double.tryParse(value2.toString()) ?? 0.0;
          _motorRpmController.text = setRPM.toStringAsFixed(1);
        });
      }
    });

    _databaseReference.child('RT_Temp').onValue.listen((event) {
      final value3 = event.snapshot.value;
      if (value3 != null) {
        setState(() {
          rtTemp = double.tryParse(value3.toString()) ?? 0.0;
          _temperatureController.text = rtTemp.toStringAsFixed(2);
        });
      }
    });

    _databaseReference.child('set_Temp').onValue.listen((event) {
      final value4 = event.snapshot.value;
      if (value4 != null) {
        setState(() {
          setTemp = double.tryParse(value4.toString()) ?? 0.0;
          _temperatureController.text = setTemp.toStringAsFixed(2);
        });
      }
    });

    _databaseReference.child('UV').onValue.listen((event) {
      final value5 = event.snapshot.value;
      if (value5 != null) {
        setState(() {
          UV = value5 as bool;
        });
      }
    });

    _databaseReference.child('LED').onValue.listen((event) {
      final value6 = event.snapshot.value;
      if (value6 != null) {
        setState(() {
          LED = value6 as bool;
        });
      }
    });

    _databaseReference.onValue.listen((event) {
      final value7 = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        if (value7 != null) {
          _data = value7.cast<String, dynamic>();
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

  // FCM 토큰 가져오기
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

  // 온도 데이터를 업데이트
  void _updateTempData() {
    for (int i = 0; i < tempKeys.length; i++) {
      _updateTemp(tempKeys[i], tempSpots[i]);
    }
  }

  // 특정 온도 데이터를 업데이트
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

  // 컨트롤 값 업데이트
  void _updateControlValues() {
    if (_data.containsKey('RT_RPM')) {
      rtRPM = double.tryParse(_data['RT_RPM'].toString()) ?? 0;
      _motorRpmController.text = rtRPM.toStringAsFixed(1);
    }
    if (_data.containsKey('set_Temp')) {
      double newTemp = double.tryParse(_data['set_Temp'].toString()) ?? 0.0;
      if (newTemp >= -55 && newTemp <= 125) { // 온도 범위 체크
        setTemp = newTemp;
        _temperatureController.text = setTemp.toStringAsFixed(2);
      }
    }
    if (_data.containsKey('UV')) {
      UV = _data['UV'] == true;
    }
    if (_data.containsKey('LED')) {
      LED = _data['LED'] == true;
    }
  }

  // 온도 알림 체크 및 메시지 전송
  void _checkTemperatureAndSendMessage() {
    if (_data['temp1'] >= 100) {
      NotificationService.sendNotification(
        'Temperature Alert',
        'The temperature has reached or exceeded $setTemp°C.',
      );
    }
  }

  // 그래프 리셋
  void _resetGraph() {
    setState(() {
      for (int i = 0; i < tempSpots.length; i++) {
        tempSpots[i].clear();
      }
    });
  }

  // UV 상태 토글
  void _toggleUV() {
    setState(() {
      UV = !UV;
      _databaseReference.child('UV').set(UV);
    });
  }

  // LED 상태 토글
  void _toggleLED() {
    setState(() {
      LED = !LED;
      _databaseReference.child('LED').set(LED);
    });
  }

  // 목표 온도 설정
  void _setTargetTemperature() {
    double newTemp = double.tryParse(_temperatureController.text) ?? 0.0;
    if (newTemp >= 0 && newTemp <= 80) { // Set Temp 범위 체크
      setState(() {
        setTemp = newTemp;
        _databaseReference.child('set_Temp').set(setTemp);
        _temperatureController.text = setTemp.toStringAsFixed(2);
      });
    } else {
      // 잘못된 범위 값 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid temperature between 0 and 80.')),
      );
    }
  }

  // 모터 RPM 설정
  void _setMotorRpm() {
    double newRpm = double.tryParse(_motorRpmController.text) ?? 0.0;
    if (newRpm >= 0 && newRpm <= 3000) {
      setState(() {
        setRPM = newRpm;
        _databaseReference.child('set_RPM').set(setRPM);
        _motorRpmController.text = setRPM.toStringAsFixed(1);
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
              leading: Icon(Icons.settings),
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
              leading: Icon(Icons.settings),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: DataItem(data: _data, dataKey: 'RT_Temp')),
                  Expanded(child: DataItem(data: _data, dataKey: 'RT_RPM')),
                  Expanded(child: DataItem(data: _data, dataKey: 'PH')),
                ],
              ),
              // 추가된 줄
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: DataItem(data: _data, dataKey: 'temp6')),
                  Expanded(child: DataItem(data: _data, dataKey: 'temp7')),
                  Expanded(child: DataItem(data: _data, dataKey: 'temp8')),
                ],
              ),
              SizedBox(height: 20),
              _buildDropdown(),
              SizedBox(height: 20),
              _buildGraph(),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('RT RPM: ${rtRPM.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ControlSlider(
                          label: 'Set RPM: ${setRPM.toStringAsFixed(1)}',
                          value: setRPM,
                          min: 0,
                          max: 3000,
                          onChanged: (value2) {
                            setState(() {
                              setRPM = value2;
                              _motorRpmController.text = setRPM.toStringAsFixed(1);
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
                          onChanged: (value2) {
                            double? newValue1 = double.tryParse(value2);
                            if (newValue1 != null && newValue1 >= 0 && newValue1 <= 3000) {
                              setState(() {
                                setRPM = newValue1;
                                _databaseReference.child('set_RPM').set(setRPM);
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
                        Text('RT Temp: ${rtTemp.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ControlSlider(
                          label: 'Set Temp: ${setTemp.toStringAsFixed(2)}',
                          value: setTemp,
                          min: 0,
                          max: 80,
                          onChanged: (value4) {
                            setState(() {
                              setTemp = value4;
                              _temperatureController.text = setTemp.toStringAsFixed(2);
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
                          onChanged: (value4) {
                            double? newValue2 = double.tryParse(value4);
                            if (newValue2 != null && newValue2 >= 0 && newValue2 <= 80) {
                              setState(() {
                                setTemp = newValue2;
                                _databaseReference.child('set_Temp').set(setTemp);
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
                        Text('UV Status: ${UV ? "On" : "Off"}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ElevatedButton(
                          onPressed: _toggleUV,
                          child: Text(UV ? 'Set UV Off' : 'Set UV On'),
                        ),
                        Text('LED Status: ${LED ? "On" : "Off"}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ElevatedButton(
                          onPressed: _toggleLED,
                          child: Text(LED ? 'Set LED Off' : 'Set LED On'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 드롭다운 메뉴 위젯 생성
  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: selectedTemp,
      onChanged: (String? newValue3) {
        setState(() {
          selectedTemp = newValue3!;
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

  // 그래프 위젯 생성
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
              color: Colors.red,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  // 로그아웃 함수
  void logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      print("Logout error :$e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그아웃 실패')),
      );
    }
  }
}
