import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart'; // fl_chart 임포트 추가
import 'firebase_options.dart';

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
  bool showAvg = false; // showAvg 변수 추가

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref();
    _databaseReference.onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        if (value != null) {
          _data = value.cast<String, dynamic>();
        } else {
          _data = {};
        }
      });
    });
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
            _buildDataItem('temp1'),
            _buildDataItem('temp2'),
            _buildDataItem('temp3'),
            SizedBox(height: 20),
            _buildGraph(), // 그래프 추가
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(String key) {
    return Text(
      '$key: ${_data[key]?.toString() ?? 'Loading...'}',
      style: TextStyle(fontSize: 20),
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
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
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
              const style = TextStyle(
                color: Color(0xff68737d),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              );
              Widget text;
              switch (value.toInt()) {
                case 2:
                  text = const Text('MAR', style: style);
                  break;
                case 5:
                  text = const Text('JUN', style: style);
                  break;
                case 8:
                  text = const Text('SEP', style: style);
                  break;
                default:
                  text = const Text('', style: style);
                  break;
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8.0,
                child: text,
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const style = TextStyle(
                color: Color(0xff67727d),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              );
              Widget text;
              switch (value.toInt()) {
                case 1:
                  text = const Text('10k', style: style);
                  break;
                case 3:
                  text = const Text('30k', style: style);
                  break;
                case 5:
                  text = const Text('50k', style: style);
                  break;
                default:
                  text = const Text('', style: style);
                  break;
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 12.0,
                child: text,
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
      maxX: 11,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: [
            FlSpot(0, 3),
            FlSpot(2.6, 2),
            FlSpot(4.9, 5),
            FlSpot(6.8, 3.1),
            FlSpot(8, 4),
            FlSpot(9.5, 3),
            FlSpot(11, 4),
          ],
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
              const style = TextStyle(
                color: Color(0xff68737d),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              );
              Widget text;
              switch (value.toInt()) {
                case 2:
                  text = const Text('MAR', style: style);
                  break;
                case 5:
                  text = const Text('JUN', style: style);
                  break;
                case 8:
                  text = const Text('SEP', style: style);
                  break;
                default:
                  text = const Text('', style: style);
                  break;
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 8.0,
                child: text,
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const style = TextStyle(
                color: Color(0xff67727d),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              );
              Widget text;
              switch (value.toInt()) {
                case 1:
                  text = const Text('10k', style: style);
                  break;
                case 3:
                  text = const Text('30k', style: style);
                  break;
                case 5:
                  text = const Text('50k', style: style);
                  break;
                default:
                  text = const Text('', style: style);
                  break;
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 12.0,
                child: text,
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
      maxX: 11,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: [
            FlSpot(0, 3.44),
            FlSpot(2.6, 3.44),
            FlSpot(4.9, 3.44),
            FlSpot(6.8, 3.44),
            FlSpot(8, 3.44),
            FlSpot(9.5, 3.44),
            FlSpot(11, 3.44),
          ],
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
