import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true; // 알림 활성화 여부
  double _fontSize = 16.0; // 글꼴 크기
  String _theme = 'Light'; // 테마 설정
  String _language = 'English'; // 언어 설정

  final List<String> _themes = ['Light', 'Dark']; // 테마 옵션
  final List<String> _languages = ['English', 'Korean', 'Spanish']; // 언어 옵션

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          SwitchListTile(
            title: Text('Enable Notifications'),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          ListTile(
            title: Text('Font Size'),
            subtitle: Slider(
              value: _fontSize,
              min: 12.0,
              max: 24.0,
              divisions: 6,
              label: '${_fontSize.toInt()}',
              onChanged: (double value) {
                setState(() {
                  _fontSize = value;
                });
              },
            ),
          ),
          ListTile(
            title: Text('Theme'),
            trailing: DropdownButton<String>(
              value: _theme,
              onChanged: (String? newValue) {
                setState(() {
                  _theme = newValue!;
                });
              },
              items: _themes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: Text('Language'),
            trailing: DropdownButton<String>(
              value: _language,
              onChanged: (String? newValue) {
                setState(() {
                  _language = newValue!;
                });
              },
              items: _languages.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _saveSettings();
            },
            child: Text('Save Settings'),
          ),
        ],
      ),
    );
  }

  // 설정 저장 함수 (예: SharedPreferences 사용)
  void _saveSettings() {
    // 설정 저장 로직 구현 (예: SharedPreferences 또는 Firestore)
    print('Settings saved: Notifications: $_notificationsEnabled, Font Size: $_fontSize, Theme: $_theme, Language: $_language');
  }
}
