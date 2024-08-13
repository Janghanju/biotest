import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../widgets/control_slider.dart';
import '../widgets/dataitem.dart';
import 'BluetoothDeviceManager.dart';
import 'SettingsScreen.dart';
import 'deviceStorage.dart';
import 'getItem.dart';
import 'login.dart';
//import 'register.dart'; // Import the new registration widget

class HomeScreen extends StatefulWidget {
  final String title;

  const HomeScreen({Key? key, required this.title}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic> _data = {};
  List<List<FlSpot>> tempSpots = List.generate(14, (_) => <FlSpot>[]); // 온도 및 RPM 데이터 포인트 저장
  double rtRPM = 0; // 실시간 RT RPM 값
  double setRPM = 0.0; // 설정된 RPM 값
  double setRPM2 = 0.0; // 두 번째 설정된 RPM 값
  double rtRPM2 = 0.0; // 실시간 RT RPM2 값
  double rtTemp = 0.0; // 실시간 RT 온도 값
  double rtTemp2 = 0.0; // 실시간 RT 온도2 값
  double setTemp = 0.0; // 설정된 온도 값
  double setTemp2 = 0.0; // 두 번째 설정된 온도 값
  double phValue = 0.0; // PH 측정 값
  double userSetRPM = 0.0; // 사용자 입력 Set RPM
  double userSetRPM2 = 0.0; // 사용자 입력 Set RPM2
  double userSetTemp = 0.0; // 사용자 입력 Set Temp
  double userSetTemp2 = 0.0; // 사용자 입력 Set Temp2
  bool UV = false; // UV 상태
  bool LED = false; // LED 상태

  late VideoPlayerController _videoPlayerController;
  String? _fcmToken;

  String selectedTemp = 'RT_Temp'; // 선택된 온도 키
  final List<String> tempKeys = [
    'RT_Temp', 'RT_RPM', 'PH', 'UV', 'LED', 'RT_Temp2', 'RT_RPM2', // 키 추가
    'temp1', 'temp2', 'temp3', 'temp4', 'temp5', 'temp6', 'temp7'
  ]; // 온도 및 RPM 키 목록
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _motorRpmController = TextEditingController();
  final TextEditingController _temperatureController2 = TextEditingController(); // 추가된 컨트롤러
  final TextEditingController _motorRpmController2 = TextEditingController(); // 추가된 컨트롤러

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref();

    // 모든 데이터에 대한 리스너 설정
    _databaseReference.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _data = data.cast<String, dynamic>();
          _updateAllValues();
          _updateTempData();
        });
      } else {
        setState(() {
          _data = {};
        });
      }
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

  // 모든 값을 업데이트
  void _updateAllValues() {
    rtRPM = double.tryParse(_data['RT_RPM']?.toString() ?? '0.0') ?? 0.0;
    setRPM = double.tryParse(_data['set_RPM']?.toString() ?? '0.0') ?? 0.0;
    setRPM2 = double.tryParse(_data['set_RPM2']?.toString() ?? '0.0') ?? 0.0; // 추가된 값
    rtRPM2 = double.tryParse(_data['RT_RPM2']?.toString() ?? '0.0') ?? 0.0; // 추가된 값
    rtTemp = double.tryParse(_data['RT_Temp']?.toString() ?? '0.0') ?? 0.0;
    setTemp = double.tryParse(_data['set_Temp']?.toString() ?? '0.0') ?? 0.0;
    rtTemp2 = double.tryParse(_data['RT_Temp2']?.toString() ?? '0.0') ?? 0.0; // 추가된 값
    setTemp2 = double.tryParse(_data['set_Temp2']?.toString() ?? '0.0') ?? 0.0; // 추가된 값
    phValue = double.tryParse(_data['PH']?.toString() ?? '0.0') ?? 0.0;
    UV = _data['UV'] ?? false;
    LED = _data['LED'] ?? false;

    // 데이터베이스에서 초기값을 가져올 때만 텍스트필드 업데이트
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

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _temperatureController.dispose();
    _motorRpmController.dispose();
    _temperatureController2.dispose();
    _motorRpmController2.dispose();
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
        userSetTemp = newTemp;
        _databaseReference.child('set_Temp').set(userSetTemp);
      });
    } else {
      // 잘못된 범위 값 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid temperature between 0 and 80.')),
      );
    }
  }

  // 추가된 목표 온도2 설정
  void _setTargetTemperature2() {
    double newTemp2 = double.tryParse(_temperatureController2.text) ?? 0.0;
    if (newTemp2 >= 0 && newTemp2 <= 80) { // Set Temp 범위 체크
      setState(() {
        userSetTemp2 = newTemp2;
        _databaseReference.child('set_Temp2').set(userSetTemp2);
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
        userSetRPM = newRpm;
        _databaseReference.child('set_RPM').set(userSetRPM);
      });
    } else {
      // 잘못된 범위 값 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid RPM between 0 and 3000.')),
      );
    }
  }

  // 추가된 모터 RPM2 설정
  void _setMotorRpm2() {
    double newRpm2 = double.tryParse(_motorRpmController2.text) ?? 0.0;
    if (newRpm2 >= 0 && newRpm2 <= 3000) {
      setState(() {
        userSetRPM2 = newRpm2;
        _databaseReference.child('set_RPM2').set(userSetRPM2);
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
                MaterialPageRoute(builder: (context) => SettingsScreen());
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
                  Expanded(child: DataItem(data: _data, dataKey: 'RT_Temp2')), // 추가된 UI 요소
                  Expanded(child: DataItem(data: _data, dataKey: 'RT_RPM2')), // 추가된 UI 요소
                  Expanded(child: DataItem(data: _data, dataKey: 'PH2')), // 대체된 UI 요소
                ],
              ),
              SizedBox(height: 20),
              _buildDropdown(),
              SizedBox(height: 20),
              _buildGraph(),
              SizedBox(height: 20),
              // 기존 설정 UI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('RT RPM: ${rtRPM.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)),
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
                        Text('RT Temp: ${rtTemp.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ControlSlider(
                          label: 'Set Temp: ${userSetTemp.toStringAsFixed(2)}',
                          value: userSetTemp,
                          min: 0,
                          max: 80,
                          onChanged: (value) {
                            setState(() {
                              userSetTemp = value;
                              _temperatureController.text = userSetTemp.toStringAsFixed(2);
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
              SizedBox(height: 20),
              // 추가된 설정 UI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('RT RPM2: ${rtRPM2.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)), // 실시간 RT RPM2 표시
                        ControlSlider(
                          label: 'Set RPM2: ${userSetRPM2.toStringAsFixed(1)}',
                          value: userSetRPM2,
                          min: 0,
                          max: 3000,
                          onChanged: (value) {
                            setState(() {
                              userSetRPM2 = value;
                              _motorRpmController2.text = userSetRPM2.toStringAsFixed(1);
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
                        Text('RT Temp2: ${rtTemp2.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)), // 실시간 RT Temp2 표시
                        ControlSlider(
                          label: 'Set Temp2: ${userSetTemp2.toStringAsFixed(2)}',
                          value: userSetTemp2,
                          min: 0,
                          max: 80,
                          onChanged: (value) {
                            setState(() {
                              userSetTemp2 = value;
                              _temperatureController2.text = userSetTemp2.toStringAsFixed(2);
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
              color: Colors.blue,
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