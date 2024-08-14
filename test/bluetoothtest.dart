import 'package:biotest/screens/BluetoothDeviceManager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_blue/flutter_blue.dart';

// FlutterBlue와 FirebaseAuth의 Mock 클래스 생성
class MockFlutterBlue extends Mock implements FlutterBlue {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockBluetoothDevice extends Mock implements BluetoothDevice {}
class MockBluetoothCharacteristic extends Mock implements BluetoothCharacteristic {}

void main() {
  late MockFlutterBlue mockFlutterBlue;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockBluetoothDevice mockBluetoothDevice;
  late MockBluetoothCharacteristic mockBluetoothCharacteristic;

  setUp(() {
    mockFlutterBlue = MockFlutterBlue();
    mockFirebaseAuth = MockFirebaseAuth();
    mockBluetoothDevice = MockBluetoothDevice();
    mockBluetoothCharacteristic = MockBluetoothCharacteristic();
  });

  testWidgets('displays scanning results and registers device', (WidgetTester tester) async {
    // Mock scanning result

    when(mockBluetoothDevice.name).thenReturn('Test Device');
    when(mockBluetoothDevice.id).thenReturn(DeviceIdentifier('00:11:22:33:44:55'));

    // Widget을 빌드하여 테스트 시작
    await tester.pumpWidget(MaterialApp(
      home: BluetoothDeviceRegistration(),
    ));

    // 스캔된 장치 이름이 목록에 나타나는지 확인
    expect(find.text('Test Device'), findsOneWidget);
    expect(find.text('00:11:22:33:44:55'), findsOneWidget);

    // 장치를 클릭하여 등록
    await tester.tap(find.text('Test Device'));
    await tester.pump();

    // 기기가 등록되었다는 메시지가 화면에 표시되는지 확인
    expect(find.text('Device Test Device registered successfully'), findsOneWidget);
  });

  testWidgets('displays no devices found message when scan results are empty', (WidgetTester tester) async {
    when(mockFlutterBlue.scanResults).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(MaterialApp(
      home: BluetoothDeviceRegistration(),
    ));

    expect(find.text('No devices found.'), findsOneWidget);
  });
}
