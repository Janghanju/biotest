import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'firebase_options.dart';
import 'package:video_player/video_player.dart';

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
  List<FlSpot> temp1Spots = [];
  List<FlSpot> temp2Spots = [];
  List<FlSpot> temp3Spots = [];
  late VideoPlayerController _controller;
  double motorRpm = 0.0;
  double targetTemperature = 0.0;

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref();
    _databaseReference.onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        if (value != null) {
          _data = value.cast<String, dynamic>();
          _updateTempData(); // temp 데이터 업데이트
        } else {
          _data = {};
        }
      });
    });

    _controller = VideoPlayerController.network(
      'rtsp://210.99.70.120:1935/live/cctv001.stream',
    )
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateTempData() {
    _updateTemp('temp1', temp1Spots);
    _updateTemp('temp2', temp2Spots);
    _updateTemp('temp3', temp3Spots);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.lightBlue, // 앱바 색상을 밝은 색으로 변경
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
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
        color: Colors.grey[200], // 밝은 배경 색상으로 변경
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
              _buildSlider('Motor RPM', motorRpm, (value) {
                setState(() {
                  motorRpm = value;
                  _databaseReference.child('motorRpm').set(motorRpm);
                });
              }),
              _buildSlider('Target Temperature', targetTemperature, (value) {
                setState(() {
                  targetTemperature = value;
                  _databaseReference.child('targetTemperature').set(targetTemperature);
                });
              }),
              Container(
                color: Colors.lightBlue[50], // 하얀 부분을 밝은 색상으로 변경
                height: 100,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataItem(String key) {
    return Text(
      '$key: ${_data[key]?.toString() ?? 'Loading...'}',
      style: TextStyle(fontSize: 20, color: Colors.black), // 밝은 배경에 맞는 텍스트 색상 변경
    );
  }

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

  Widget _buildGraph() {
    return SafeArea(
      child: Column(
        children: <Widget>[
          TextButton(
            child: Text(
              showAvg ? '평균값 O' : '평균값 X',
              style: TextStyle(
                color: showAvg ? Colors.black.withOpacity(0.5) : Colors.black, // 밝은 배경에 맞는 텍스트 색상 변경
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
                color: Colors.white, // 그래프 배경을 밝은 색상으로 변경
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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

  LineChartData mainChart() {
    List<Color> gradientColors1 = [const Color(0xff23b6e6), const Color(0xff02d39a)];
    List<Color> gradientColors2 = [const Color(0xffff0000), const Color(0xff800000)];
    List<Color> gradientColors3 = [const Color(0xff8b00ff), const Color(0xff4b0082)];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey,
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey,
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
              final DateTime time = DateTime.now().subtract(Duration(seconds: (60 - value.toInt())));
              final String formattedTime = "${time.hour}:${time.minute}:${time.second}";
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8.0,
                child: Text(formattedTime, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
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
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              );
            },
            reservedSize: 28,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey, width: 1),
      ),
      minX: 0,
      maxX: 59,
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: temp1Spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors1,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors1.map((color) => color.withOpacity(0.3)).toList(),
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        LineChartBarData(
          spots: temp2Spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors2,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors2.map((color) => color.withOpacity(0.3)).toList(),
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        LineChartBarData(
          spots: temp3Spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors3,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors3.map((color) => color.withOpacity(0.3)).toList(),
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ],
    );
  }

  LineChartData avgChart() {
    List<Color> gradientColors = [const Color(0xff23b6e6), const Color(0xff02d39a)];
    return LineChartData(
      lineTouchData: LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey,
            strokeWidth: 1,
          );
        },
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey,
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
              final DateTime time = DateTime.now().subtract(Duration(seconds: (60 - value.toInt())));
              final String formattedTime = "${time.hour}:${time.minute}:${time.second}";
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8.0,
                child: Text(formattedTime, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
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
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              );
            },
            reservedSize: 28,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey, width: 1),
      ),
      minX: 0,
      maxX: 59,
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(60, (index) => FlSpot(index.toDouble(), 50)), // 예제 평균 데이터
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

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.black)),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
