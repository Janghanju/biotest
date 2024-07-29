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
  List<FlSpot> temp1Spots = [];
  List<FlSpot> temp2Spots = [];
  List<FlSpot> temp3Spots = [];
  late VideoPlayerController _controller;
  double motorRpm = 0.0;
  double targetTemperature = 0.0;
  double rtMotor = 0.0;
  double rtTemp = 0.0;

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
        } else {
          _data = {};
        }
      });
    });

    _controller = VideoPlayerController.network(
      //'http://210.99.70.120:1935/live/cctv018.stream/playlist.m3u8',
      'https://www.shutterstock.com/shutterstock/videos/1111470671/preview/stock-footage-electric-light-bulb-bright-polygonal-connections-on-a-dark-blue-background-technology-concept.webm',
    )..initialize().then((_) {
      setState(() {});
      _controller.play();
    });
  }

  @overrides
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

  void _updateControlValues() {
    if (_data.containsKey('motorRpm')) {
      motorRpm = double.tryParse(_data['motorRpm'].toString()) ?? 0.0;
    }
    if (_data.containsKey('targetTemperature')) {
      targetTemperature =
          double.tryParse(_data['targetTemperature'].toString()) ?? 0.0;
    }
    if (_data.containsKey('rtMotor')) {
      rtMotor = double.tryParse(_data['rtMotor'].toString()) ?? 0.0;
    }
    if (_data.containsKey('rtTemp')) {
      rtTemp = double.tryParse(_data['rtTemp'].toString()) ?? 0.0;
    }
  }

  void _resetGraph() {
    setState(() {
      temp1Spots.clear();
      temp2Spots.clear();
      temp3Spots.clear();
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('RT Motor: ${rtMotor.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 16, color: Colors.black)),
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
                      Text(
                          'RT Temp: ${rtTemp.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16, color: Colors.black)),
                      _buildSlider(
                          'RT Temp', targetTemperature, -55.00, 125.00,
                              (value) {
                            setState(() {
                              targetTemperature = value;
                            });
                          }),
                      ElevatedButton(
                        onPressed: () {
                          _databaseReference
                              .child('targetTemperature')
                              .set(targetTemperature);
                        },
                        child: Text('Set Target Temperature'),
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

  Widget _buildDataItem(String key) {
    return Text(
      '$key: ${_data[key]?.toString() ?? 'Loading...'}',
      style: TextStyle(fontSize: 20, color: Colors.black),
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
          AspectRatio(
            aspectRatio: 1.5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: LineChart(
                  mainChart(),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegend('Temp 1', Colors.blue),
              _buildLegend('Temp 2', Colors.red),
              _buildLegend('Temp 3', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          color: color,
        ),
        SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.black)),
      ],
    );
  }

  LineChartData mainChart() {
    List<Color> gradientColors1 = [
      const Color(0xff23b6e6),
      const Color(0xff02d39a)
    ];
    List<Color> gradientColors2 = [
      const Color(0xffff0000),
      const Color(0xff800000)
    ];
    List<Color> gradientColors3 = [
      const Color(0xff8b00ff),
      const Color(0xff4b0082)
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 10,
        verticalInterval: 10,
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
              if (value % 5 == 0) {
                final DateTime time = DateTime.now()
                    .subtract(Duration(seconds: (60 - value.toInt())));
                final String formattedTime =
                    "${time.hour}:${time.minute}:${time.second}";
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(formattedTime,
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                );
              } else {
                return Container();
              }
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
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
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
      lineBarsData: [
        LineChartBarData(
          spots: temp1Spots,
          isCurved: true,
          gradient: LinearGradient(
            colors: gradientColors1,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: false,
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
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: false,
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
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: false,
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.black)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 100).toInt(),
          label: value.toStringAsFixed(label == 'Target Temperature' ? 2 : 0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
