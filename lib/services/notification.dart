import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static const String serverKey = 'YOUR_SERVER_KEY';

  static Future<void> sendNotification(String title, String body) async {
    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: json.encode({
        'notification': {
          'title': title,
          'body': body,
        },
        'priority': 'high',
        'to': '/topics/temperature',
      }),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification');
    }
  }
}