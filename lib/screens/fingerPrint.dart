import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FingerprintScreen extends StatefulWidget {
  @override
  _FingerprintScreenState createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _errorMessage = '';

  Future<void> _authenticateWithBiometrics() async {
    try {
      final isBiometricSupported = await _localAuth.isDeviceSupported();
      if (!isBiometricSupported) {
        setState(() {
          _errorMessage = 'Biometric authentication is not supported on this device.';
        });
        return;
      }

      final isBiometricAvailable = await _localAuth.canCheckBiometrics;
      if (!isBiometricAvailable) {
        setState(() {
          _errorMessage = 'Biometric authentication is not available.';
        });
        return;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        // 지문 인증 성공 시 로그인 처리
        User? user = _auth.currentUser;

        if (user != null) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() {
            _errorMessage = 'No user is currently logged in.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Biometric authentication failed.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred during authentication.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fingerprint Authentication'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _authenticateWithBiometrics,
              child: Text('Authenticate with Fingerprint'),
            ),
            if (_errorMessage.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
