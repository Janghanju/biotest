import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart'; // fl_chart 임포트 추가
import 'firebase_options.dart';
import 'package:video_player/video_player.dart'; // 비디오 플레이어 패키지 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
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
      home: const MyHomePage(title: 'Bio-reactor Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DatabaseReference _databaseReference;
  Map<String, dynamic> _data = {};
  bool showAvg = false;
  List<FlSpot> temp1Spots = []; // temp1 데이터를 위한 리스트
  late VideoPlayerController _controller; // 비디오 컨트롤러

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref();
    _databaseReference.onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        if (value != null) {
          _data = value.cast<String, dynamic>();
          _updateTemp1Data(); // temp1 데이터 업데이트
        } else {
          _data = {};
        }
      });
    });

    // 비디오 컨트롤러 초기화
    _controller = VideoPlayerController.network(
      'https://www.example.com/streaming-url', // 스트리밍 URL로 대체
    )
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose(); // 비디오 컨트롤러 해제
    super.dispose();
  }

  void _updateTemp1Data() {
    if (_data.containsKey('temp1')) {
      double temp1Value = double.tryParse(_data['temp1'].toString()) ?? 0.0;
      if (temp1Spots.length >= 60) {
        temp1Spots.removeAt(0); // 60개의 데이터를 초과하면 가장 오래된 데이터 제거
      }
      temp1Spots.add(FlSpot(temp1Spots.length.toDouble(), temp1Value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.green, // 앱바 색상 변경
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // 데이터 새로 고침 로직 추가
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
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildStreamingView(), // 스트리밍 화면 추가
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDataItem('temp1'),
                _buildDataItem('temp2'),
                _buildDataItem('temp3'),
              ],
            ),
            SizedBox(height: 20),
            _buildGraph(), // 그래프 추가
          ],
        ),
      ),
    );
  }

  // temp1, temp2, temp3 값을 표시하는 위젯
  Widget _buildDataItem(String key) {
    return Text(
      '$key: ${_data[key]?.toString() ?? 'Loading...'}',
      style: TextStyle(fontSize: 20),
    );
  }

  // 스트리밍 화면을 표시하는 위젯
  Widget _buildStreamingView() {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    )
        : Container(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // 그래프를 표시하는 위젯
  Widget _buildGraph() {
    return SafeArea(
      child: Column(
        children: <Widget>[
          TextButton(
            child: Text(
              showAvg ? '평균값 O' : '평균값 X',
              style: TextStyle(
                color: showAvg ? Colors.white.withOpacity(0.5) : Colors.white,
              ),
            ),
            onPressed: () {
              setState(() {
                showAvg = !showAvg;
              });
            },
          ),
          AspectRatio(
            aspectRatio: 3 / 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
                color: Color(0xff232d37),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20), // 좌우 여백 추가
                child: LineChart(
                  showAvg ? avgChart() : mainChart(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 주 그래프 데이터 설정
  LineChartData mainChart() {
    List<Color> gradientColors = [
      const Color(0xff23b6e6),
      const Color(0xff02d39a),
    ];
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Color(0xff37434d),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Color(0xff37434d),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              // x축 값을 시간 값으로 설정
              final DateTime time = DateTime.now().subtract(Duration(seconds: (60 - value.toInt())));
              final String formattedTime = "${time.hour}:${time.minute}:${time.second}";
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8.0,
                child: Text(formattedTime, style: const TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 12)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 12.0,
                child: Text(
                  value.toString(),
                  style: const TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 15),
                ),
              );
            },
            reservedSize: 28,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d), width: 1),
      ),
      minX: 0,
      maxX: 59,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: temp1Spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors.map((color) => color.withOpacity(0.3)).toList(),
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ],
    );
  }

  // 평균 그래프 데이터 설정
  LineChartData avgChart() {
    List<Color> gradientColors = [
      const Color(0xff23b6e6),
      const Color(0xff02d39a),
    ];
    return LineChartData(
      lineTouchData: LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: const Color(0xff37434d),
            strokeWidth: 1,
          );
        },
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: const Color(0xff37434d),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              final DateTime time = DateTime.now().subtract(Duration(seconds: (30 - value.toInt())));
              final String formattedTime = "${time.hour}:${time.minute}:${time.second}";
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8.0,
                child: Text(formattedTime, style: const TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 12)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 12.0,
                child: Text(
                  value.toString(),
                  style: const TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 15),
                ),
              );
            },
            reservedSize: 28,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d), width: 1),
      ),
      minX: 0,
      maxX: 59,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(60, (index) => FlSpot(index.toDouble(), 3.44)), // 예제 평균 데이터
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              ColorTween(begin: gradientColors[0], end: gradientColors[1]).lerp(0.2)!,
              ColorTween(begin: gradientColors[0], end: gradientColors[1]).lerp(0.2)!,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                ColorTween(begin: gradientColors[0], end: gradientColors[1]).lerp(0.2)!.withOpacity(0.1),
                ColorTween(begin: gradientColors[0], end: gradientColors[1]).lerp(0.2)!.withOpacity(0.1),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ],
    );
  }
}
