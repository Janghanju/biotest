import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'device.dart';

class BluetoothDeviceRegistration extends StatefulWidget {
  final String title;

  BluetoothDeviceRegistration({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<BluetoothDeviceRegistration> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<ScanResult> scanResultList = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // 블루투스 초기화
    initBle();
  }

  void initBle() {
    // BLE 스캔 상태 얻기 위한 리스너
    flutterBlue.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  // 스캔 시작/정지 함수
  void scan() async {
    if (!_isScanning) {
      // 스캔 중이 아니라면 기존에 스캔된 리스트 삭제
      scanResultList.clear();
      // 스캔 시작, 제한 시간 10초로 변경
      flutterBlue.startScan(timeout: Duration(seconds: 10));
      // 스캔 결과 리스너
      flutterBlue.scanResults.listen((results) {
        setState(() {
          scanResultList = results;
        });
      });
    } else {
      // 스캔 중이라면 스캔 정지
      flutterBlue.stopScan();
    }
  }

  // 장치의 신호값 위젯
  Widget deviceSignal(ScanResult r) {
    return Text(r.rssi.toString());
  }

  // 장치의 MAC 주소 위젯
  Widget deviceMacAddress(ScanResult r) {
    return Text(r.device.id.toString());
  }

  // 장치의 명 위젯
  Widget deviceName(ScanResult r) {
    String name = '';

    if (r.device.name.isNotEmpty) {
      name = r.device.name;
    } else if (r.advertisementData.localName.isNotEmpty) {
      name = r.advertisementData.localName;
    } else {
      name = 'N/A';
    }
    return Text(name);
  }

  // BLE 아이콘 위젯
  Widget leading(ScanResult r) {
    return CircleAvatar(
      child: Icon(
        Icons.bluetooth,
        color: Colors.white,
      ),
      backgroundColor: Colors.cyan,
    );
  }

  // 장치 아이템을 탭 했을때 호출 되는 함수
  void onTap(ScanResult r) {
    print('${r.device.name}');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DeviceScreen(device: r.device)),
    );
  }

  // 장치 아이템 위젯
  Widget listItem(ScanResult r) {
    return ListTile(
      onTap: () => onTap(r),
      leading: leading(r),
      title: deviceName(r),
      subtitle: deviceMacAddress(r),
      trailing: deviceSignal(r),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        // 장치 리스트 출력
        child: ListView.separated(
          itemCount: scanResultList.length,
          itemBuilder: (context, index) {
            return listItem(scanResultList[index]);
          },
          separatorBuilder: (BuildContext context, int index) {
            return Divider();
          },
        ),
      ),
      // 장치 검색 or 검색 중지
      floatingActionButton: FloatingActionButton(
        onPressed: scan,
        // 스캔 중이라면 stop 아이콘을, 정지상태라면 search 아이콘으로 표시
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}
