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


// HomeScreen 클래스는 블루투스 장치와의 상호작용을 처리하는 화면
class homeScreen extends StatefulWidget {
  final String title;
  final BluetoothDeviceManager deviceManager;
  final DeviceStorage deviceStorage;

  const homeScreen({Key? key, required this.title, required this.deviceManager, required this.deviceStorage}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<homeScreen> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic> _data = {}; // 데이터 저장을 위한 맵
  List<List<FlSpot>> tempSpots = List.generate(14, (_) => <FlSpot>[]); // 온도 및 RPM 데이터를 저장할 리스트
  double rtRPM = 0.0; // 실시간 RPM
  double setRPM = 0.0; // 설정된 RPM
  double setRPM2 = 0.0; // 설정된 두 번째 RPM
  double rtRPM2 = 0.0; // 실시간 두 번째 RPM
  double rtTemp = 0.0; // 실시간 온도
  double rtTemp2 = 0.0; // 실시간 두 번째 온도
  double setTemp = 0.0; // 설정된 온도
  double setTemp2 = 0.0; // 설정된 두 번째 온도
  double phValue = 0.0; // PH 값
  double userSetRPM = 0.0; // 사용자가 설정한 RPM
  double userSetRPM2 = 0.0; // 사용자가 설정한 두 번째 RPM
  double userSetTemp = 0.0; // 사용자가 설정한 온도
  double userSetTemp2 = 0.0; // 사용자가 설정한 두 번째 온도
  bool UV = false; // UV 상태
  bool LED = false; // LED 상태

  late VideoPlayerController _videoPlayerController; // 비디오 플레이어 컨트롤러
  String? _fcmToken; // FCM 토큰

  String selectedTemp = 'RT_Temp'; // 선택된 온도 키
  final List<String> tempKeys = [ // 온도 및 RPM 키 목록
    'RT_Temp', 'RT_RPM', 'PH', 'UV', 'LED', 'RT_Temp2', 'RT_RPM2',
    'temp1', 'temp2', 'temp3', 'temp4', 'temp5', 'temp6', 'temp7'
  ];
  final TextEditingController _temperatureController = TextEditingController(); // 온도 입력 컨트롤러
  final TextEditingController _motorRpmController = TextEditingController(); // RPM 입력 컨트롤러
  final TextEditingController _temperatureController2 = TextEditingController(); // 두 번째 온도 입력 컨트롤러
  final TextEditingController _motorRpmController2 = TextEditingController(); // 두 번째 RPM 입력 컨트롤러

  @override
  void initState() {
    super.initState();
    _initializeFirebase(); // Firebase 초기화
    _initializeVideoPlayer(); // 비디오 플레이어 초기화
  }

  // Firebase 초기화 함수
  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(); // Firebase 앱 초기화
    _databaseReference = FirebaseDatabase.instance.ref(); // 데이터베이스 참조 설정
    FirebaseMessaging.instance.getToken().then((token) { // FCM 토큰 가져오기
      _fcmToken = token;
      // 토큰을 데이터베이스나 서버에 저장할 필요가 있을 경우 저장
      print('FCM Token: $_fcmToken');
    });
    _initializeDataListeners(); // 데이터 리스너 초기화
  }

  // 비디오 플레이어 초기화 함수
  void _initializeVideoPlayer() {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse("http://210.99.70.120:1935/live/cctv010.stream/playlist.m3u8"), // 비디오 URL 설정
    )..initialize().then((_) {
      setState(() {}); // 비디오 플레이어가 초기화되면 상태 갱신
      _videoPlayerController.play(); // 비디오 재생
    }).catchError((error) {
      print('Video Player Initialization Error: $error'); // 초기화 오류 처리
    });
  }

  // 데이터 리스너 초기화 함수
  void _initializeDataListeners() {
    _databaseReference.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?; // 데이터베이스에서 값 가져오기
      if (data != null) {
        setState(() {
          _data = data.cast<String, dynamic>(); // 데이터를 적절한 타입으로 변환
          _updateAllValues(); // 모든 값 업데이트
          _updateTempData(); // 온도 데이터 업데이트
        });
      }
    });
  }

  // 모든 값을 업데이트하는 함수
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

    _initializeTextControllers(); // 텍스트 컨트롤러 초기화
  }

  // 텍스트 컨트롤러 초기화 함수
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

  // 온도 데이터를 업데이트하는 함수
  void _updateTempData() {
    for (int i = 0; i < tempKeys.length; i++) {
      _updateTemp(tempKeys[i], tempSpots[i]); // 각 온도 키에 대해 데이터 업데이트
    }
  }

  // 특정 온도 데이터를 업데이트하는 함수
  void _updateTemp(String key, List<FlSpot> spots) {
    if (_data.containsKey(key)) {
      double value = double.tryParse(_data[key].toString()) ?? 0.0;
      if (value >= -55 && value <= 125) { // 온도 값이 적절한 범위에 있는지 확인
        if (spots.length >= 60) {
          spots.removeAt(0); // 오래된 데이터 제거
        }
        spots.add(FlSpot(spots.length.toDouble(), value)); // 새로운 데이터 추가
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose(); // 비디오 플레이어 리소스 해제
    _temperatureController.dispose(); // 텍스트 컨트롤러 해제
    _motorRpmController.dispose();
    _temperatureController2.dispose();
    _motorRpmController2.dispose();
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
            onPressed: _resetGraph, // 그래프 리셋
          ),
        ],
      ),
      drawer: _buildDrawer(context), // 네비게이션 드로어 생성
      body: StreamBuilder(
        stream: _databaseReference.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}')); // 오류 발생 시 메시지 표시
          }
          if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
            return Center(child: CircularProgressIndicator()); // 데이터 로딩 중 표시
          }

          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map<dynamic, dynamic>? ?? {});
          final device1Status = data['device1']?['status'] as bool? ?? false; // 첫 번째 기기의 상태
          final device2Status = data['device2']?['status'] as bool? ?? false; // 두 번째 기기의 상태

          return Column(
            children: [
              Expanded(
                child: Card(
                  color: _getReactorColor(device1Status, device2Status), // 두 장치의 상태에 따라 카드 색상 결정
                  child: Center(
                    child: Text(
                      'Device 1: ${device1Status ? "Online" : "Offline"}\nDevice 2: ${device2Status ? "Online" : "Offline"}',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              _buildMainContent(context), // 메인 콘텐츠 빌드
            ],
          );
        },
      ),
    );
  }

  // 두 기기의 상태에 따른 카드 색상 반환 함수
  Color _getReactorColor(bool device1Status, bool device2Status) {
    if (device1Status && device2Status) {
      return Colors.green; // 두 기기 모두 온라인일 때 초록색
    } else if (device1Status || device2Status) {
      return Colors.orange; // 하나의 기기만 온라인일 때 주황색
    } else {
      return Colors.red; // 두 기기 모두 오프라인일 때 빨간색
    }
  }

  // 네비게이션 드로어를 생성하는 함수
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue, // 헤더 배경색
            ),
            child: Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 24), // 헤더 텍스트 스타일
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            onTap: () => Navigator.pop(context), // 홈 버튼 탭 시 드로어 닫기
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen())); // 설정 화면으로 이동
            },
          ),
          ListTile(
            leading: Icon(Icons.device_hub),
            title: Text('Device'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => DeviceAddPage())); // 기기 추가 화면으로 이동
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              logout(context); // 로그아웃 함수 호출
            },
          ),
        ],
      ),
    );
  }

  // 메인 콘텐츠를 생성하는 함수
  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: _videoPlayerController.value.isInitialized
                ? VideoPlayer(_videoPlayerController) // 비디오 플레이어 위젯
                : Center(child: CircularProgressIndicator()), // 로딩 인디케이터
          ),
          _buildDataItems(), // 데이터 아이템 빌드
          SizedBox(height: 20),
          _buildDropdown(), // 드롭다운 메뉴 빌드
          SizedBox(height: 20),
          _buildGraph(), // 그래프 빌드
          SizedBox(height: 20),
          _buildControlSliders(), // 제어 슬라이더 빌드
          SizedBox(height: 20),
          _buildAdditionalControls(), // 추가 제어 옵션 빌드
        ],
      ),
    );
  }

  // 데이터 아이템을 생성하는 함수
  Widget _buildDataItems() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: DataItem(data: _data, dataKey: 'RT_Temp')), // 실시간 온도 데이터
            Expanded(child: DataItem(data: _data, dataKey: 'RT_RPM')), // 실시간 RPM 데이터
            Expanded(child: DataItem(data: _data, dataKey: 'PH')), // PH 데이터
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: DataItem(data: _data, dataKey: 'RT_Temp2')), // 두 번째 실시간 온도 데이터
            Expanded(child: DataItem(data: _data, dataKey: 'RT_RPM2')), // 두 번째 실시간 RPM 데이터
            Expanded(child: DataItem(data: _data, dataKey: 'PH2')), // 두 번째 PH 데이터
          ],
        ),
      ],
    );
  }

  // 제어 슬라이더를 생성하는 함수
  Widget _buildControlSliders() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              Text('RT RPM: ${rtRPM.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)), // 실시간 RPM 표시
              ControlSlider(
                label: 'Set RPM: ${userSetRPM.toStringAsFixed(1)}',
                value: userSetRPM,
                min: 0,
                max: 3000,
                onChanged: (value) {
                  setState(() {
                    userSetRPM = value;
                    _motorRpmController.text = userSetRPM.toStringAsFixed(1); // 슬라이더 값 변경 시 텍스트 업데이트
                  });
                },
              ),
              TextField(
                controller: _motorRpmController,
                decoration: InputDecoration(
                  labelText: 'Set RPM Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number, // 숫자 입력 타입
                onChanged: (value) {
                  double? newValue = double.tryParse(value);
                  if (newValue != null && newValue >= 0 && newValue <= 3000) {
                    setState(() {
                      userSetRPM = newValue; // 유효한 값 입력 시 업데이트
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setMotorRpm, // 버튼 눌렀을 때 RPM 설정
                child: Text('Set RPM'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('RT Temp: ${rtTemp.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)), // 실시간 온도 표시
              ControlSlider(
                label: 'Set Temp: ${userSetTemp.toStringAsFixed(2)}',
                value: userSetTemp,
                min: 0,
                max: 80,
                onChanged: (value) {
                  setState(() {
                    userSetTemp = value;
                    _temperatureController.text = userSetTemp.toStringAsFixed(2); // 슬라이더 값 변경 시 텍스트 업데이트
                  });
                },
              ),
              TextField(
                controller: _temperatureController,
                decoration: InputDecoration(
                  labelText: 'Set Temp Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number, // 숫자 입력 타입
                onChanged: (value) {
                  double? newValue = double.tryParse(value);
                  if (newValue != null && newValue >= 0 && newValue <= 80) {
                    setState(() {
                      userSetTemp = newValue; // 유효한 값 입력 시 업데이트
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setTargetTemperature, // 버튼 눌렀을 때 온도 설정
                child: Text('Set Temp'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('UV Status: ${UV ? "On" : "Off"}', style: TextStyle(fontSize: 16, color: Colors.black)), // UV 상태 표시
              ElevatedButton(
                onPressed: _toggleUV, // UV 상태 토글
                child: Text(UV ? 'Set UV Off' : 'Set UV On'),
              ),
              Text('LED Status: ${LED ? "On" : "Off"}', style: TextStyle(fontSize: 16, color: Colors.black)), // LED 상태 표시
              ElevatedButton(
                onPressed: _toggleLED, // LED 상태 토글
                child: Text(LED ? 'Set LED Off' : 'Set LED On'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 추가 제어 옵션을 생성하는 함수
  Widget _buildAdditionalControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              Text('RT RPM2: ${rtRPM2.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.black)), // 두 번째 실시간 RPM 표시
              ControlSlider(
                label: 'Set RPM2: ${userSetRPM2.toStringAsFixed(1)}',
                value: userSetRPM2,
                min: 0,
                max: 3000,
                onChanged: (value) {
                  setState(() {
                    userSetRPM2 = value;
                    _motorRpmController2.text = userSetRPM2.toStringAsFixed(1); // 슬라이더 값 변경 시 텍스트 업데이트
                  });
                },
              ),
              TextField(
                controller: _motorRpmController2,
                decoration: InputDecoration(
                  labelText: 'Set RPM2 Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number, // 숫자 입력 타입
                onChanged: (value) {
                  double? newValue2 = double.tryParse(value);
                  if (newValue2 != null && newValue2 >= 0 && newValue2 <= 3000) {
                    setState(() {
                      userSetRPM2 = newValue2; // 유효한 값 입력 시 업데이트
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setMotorRpm2, // 버튼 눌렀을 때 두 번째 RPM 설정
                child: Text('Set RPM2'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text('RT Temp2: ${rtTemp2.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, color: Colors.black)), // 두 번째 실시간 온도 표시
              ControlSlider(
                label: 'Set Temp2: ${userSetTemp2.toStringAsFixed(2)}',
                value: userSetTemp2,
                min: 0,
                max: 80,
                onChanged: (value) {
                  setState(() {
                    userSetTemp2 = value;
                    _temperatureController2.text = userSetTemp2.toStringAsFixed(2); // 슬라이더 값 변경 시 텍스트 업데이트
                  });
                },
              ),
              TextField(
                controller: _temperatureController2,
                decoration: InputDecoration(
                  labelText: 'Set Temp2 Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number, // 숫자 입력 타입
                onChanged: (value) {
                  double? newValue2 = double.tryParse(value);
                  if (newValue2 != null && newValue2 >= 0 && newValue2 <= 80) {
                    setState(() {
                      userSetTemp2 = newValue2; // 유효한 값 입력 시 업데이트
                    });
                  }
                },
              ),
              ElevatedButton(
                onPressed: _setTargetTemperature2, // 버튼 눌렀을 때 두 번째 온도 설정
                child: Text('Set Temp2'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 드롭다운 메뉴를 생성하는 함수
  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: selectedTemp,
      onChanged: (String? newValue) {
        setState(() {
          selectedTemp = newValue!; // 선택된 값 업데이트
        });
      },
      items: tempKeys.map<DropdownMenuItem<String>>((String value) { // 드롭다운 메뉴 항목 생성
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  // 그래프를 생성하는 함수
  Widget _buildGraph() {
    int selectedIndex = tempKeys.indexOf(selectedTemp); // 선택된 키의 인덱스
    List<FlSpot> selectedSpots = tempSpots[selectedIndex]; // 선택된 데이터

    return Container(
      height: 400,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: selectedSpots.isEmpty ? [FlSpot(0, 0)] : selectedSpots, // 데이터가 없으면 기본 값 사용
              isCurved: true, // 곡선 그래프 설정
              color: Colors.blue, // 그래프 색상
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  // 그래프를 리셋하는 함수
  void _resetGraph() {
    setState(() {
      for (var spots in tempSpots) {
        spots.clear(); // 모든 데이터 지우기
      }
    });
  }

  // UV 상태를 토글하는 함수
  void _toggleUV() {
    setState(() {
      UV = !UV; // UV 상태 반전
      _databaseReference.child('UV').set(UV); // 데이터베이스에 상태 저장
    });
  }

  // LED 상태를 토글하는 함수
  void _toggleLED() {
    setState(() {
      LED = !LED; // LED 상태 반전
      _databaseReference.child('LED').set(LED); // 데이터베이스에 상태 저장
    });
  }

  // 설정된 온도를 데이터베이스에 저장하는 함수
  void _setTargetTemperature() {
    double newTemp = double.tryParse(_temperatureController.text) ?? 0.0;
    if (newTemp >= 0 && newTemp <= 80) {
      setState(() {
        userSetTemp = newTemp;
        _databaseReference.child('set_Temp').set(userSetTemp); // 데이터베이스에 온도 저장
      });
    } else {
      _showInvalidInputSnackbar('Please enter a valid temperature between 0 and 80.'); // 유효하지 않은 입력 처리
    }
  }

  // 두 번째 설정된 온도를 데이터베이스에 저장하는 함수
  void _setTargetTemperature2() {
    double newTemp2 = double.tryParse(_temperatureController2.text) ?? 0.0;
    if (newTemp2 >= 0 && newTemp2 <= 80) {
      setState(() {
        userSetTemp2 = newTemp2;
        _databaseReference.child('set_Temp2').set(userSetTemp2); // 데이터베이스에 두 번째 온도 저장
      });
    } else {
      _showInvalidInputSnackbar('Please enter a valid temperature between 0 and 80.'); // 유효하지 않은 입력 처리
    }
  }

  // 설정된 RPM을 데이터베이스에 저장하는 함수
  void _setMotorRpm() {
    double newRpm = double.tryParse(_motorRpmController.text) ?? 0.0;
    if (newRpm >= 0 && newRpm <= 3000) {
      setState(() {
        userSetRPM = newRpm;
        _databaseReference.child('set_RPM').set(userSetRPM); // 데이터베이스에 RPM 저장
      });
    } else {
      _showInvalidInputSnackbar('Please enter a valid RPM between 0 and 3000.'); // 유효하지 않은 입력 처리
    }
  }

  // 두 번째 설정된 RPM을 데이터베이스에 저장하는 함수
  void _setMotorRpm2() {
    double newRpm2 = double.tryParse(_motorRpmController2.text) ?? 0.0;
    if (newRpm2 >= 0 && newRpm2 <= 3000) {
      setState(() {
        userSetRPM2 = newRpm2;
        _databaseReference.child('set_RPM2').set(userSetRPM2); // 데이터베이스에 두 번째 RPM 저장
      });
    } else {
      _showInvalidInputSnackbar('Please enter a valid RPM between 0 and 3000.'); // 유효하지 않은 입력 처리
    }
  }

  // 유효하지 않은 입력에 대한 스낵바 표시 함수
  void _showInvalidInputSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)), // 스낵바로 메시지 표시
    );
  }

  // 로그아웃 함수
  void logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut(); // Firebase 인증 로그아웃
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()), // 로그인 화면으로 이동
            (route) => false,
      );
    } catch (e) {
      print("Logout error :$e"); // 로그아웃 오류 출력
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그아웃 실패'))); // 실패 메시지 표시
    }
  }
}

enum DeviceStatus { online, offline } // 기기 상태 열거형

