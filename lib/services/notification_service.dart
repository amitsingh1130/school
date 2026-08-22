import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission (Required for iOS and Android 13+)
    await _fcm.requestPermission();

    // Android Settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Listen for messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'school_channel', 'School Updates',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      0, message.notification?.title, message.notification?.body, details);
  }

  // Get and Save Phone Token
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<void> saveTokenToFirestore(String userId) async {
    String? token = await getToken();
    if (token != null) {
      // Find user and update token
      var userDocs = await FirebaseFirestore.instance.collection('users').where('userId', isEqualTo: userId).get();
      if (userDocs.docs.isNotEmpty) {
        await userDocs.docs.first.reference.update({'fcmToken': token});
      }
    }
  }
}
