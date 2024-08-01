import 'package:flutter/material.dart';
import 'package:flutter_qr_bar_scanner/qr_bar_scanner_camera.dart';
import 'package:flutter_beep/flutter_beep.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:wakelock/wakelock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GetItemScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR/Bar코드인식 with 진동/소리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CheckFirstLogin(),
    );
  }
}

class CheckFirstLogin extends StatefulWidget {
  @override
  _CheckFirstLoginState createState() => _CheckFirstLoginState();
}

class _CheckFirstLoginState extends State<CheckFirstLogin> {
  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  _checkFirstLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

    if (isFirstLogin) {
      prefs.setBool('isFirstLogin', false);
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MyHomePage(title: 'QR/Bar코드인식 with 진동/소리')));
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => AnotherHomePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _qrInfo = '스캔하세요';
  bool _canVibrate = true;
  bool _camState = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    bool canVibrate = await Vibrate.canVibrate;
    setState(() {
      Wakelock.enable();
      _camState = true;
      _canVibrate = canVibrate;
      _canVibrate
          ? debugPrint('This device can vibrate')
          : debugPrint('This device cannot vibrate');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  _qrCallback(String? code) {
    setState(() {
      if (code != _qrInfo) {
        FlutterBeep.beep();
        if (_canVibrate) Vibrate.feedback(FeedbackType.heavy);
      }
      _camState = false;
      _qrInfo = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 500,
            width: 500,
            child: QRBarScannerCamera(
              onError: (context, error) => Text(
                error.toString(),
                style: TextStyle(color: Colors.red),
              ),
              qrCodeCallback: (code) {
                _qrCallback(code);
              },
            ),
          ),
          FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              _qrInfo!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => DeviceAddPage()));
        },
        tooltip: '기기 추가',
        child: Icon(Icons.add),
      ),
    );
  }
}

class DeviceAddPage extends StatefulWidget {
  @override
  _DeviceAddPageState createState() => _DeviceAddPageState();
}

class _DeviceAddPageState extends State<DeviceAddPage> {
  String? _qrInfo = '기기 추가를 위해 스캔하세요';
  bool _canVibrate = true;
  bool _camState = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    bool canVibrate = await Vibrate.canVibrate;
    setState(() {
      Wakelock.enable();
      _camState = true;
      _canVibrate = canVibrate;
      _canVibrate
          ? debugPrint('This device can vibrate')
          : debugPrint('This device cannot vibrate');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  _qrCallback(String? code) {
    setState(() {
      if (code != _qrInfo) {
        FlutterBeep.beep();
        if (_canVibrate) Vibrate.feedback(FeedbackType.heavy);
      }
      _camState = false;
      _qrInfo = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('기기 추가 QR 스캔'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 500,
            width: 500,
            child: QRBarScannerCamera(
              onError: (context, error) => Text(
                error.toString(),
                style: TextStyle(color: Colors.red),
              ),
              qrCodeCallback: (code) {
                _qrCallback(code);
              },
            ),
          ),
          FittedBox(
            fit: BoxFit.fitWidth,
            child: Text(
              _qrInfo!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class AnotherHomePage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('기본 홈 화면'),
      ),
      body: Center(
        child: Text('기본 홈 화면 내용'),
      ),
    );
  }
}
