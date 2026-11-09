import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
as fln;

class VisitorNotificationService {
  VisitorNotificationService._();

  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final fln.FlutterLocalNotificationsPlugin _localNotifications =
  fln.FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initializeAndRegister() async {
    if (_initialized) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roleDoc = await FirebaseFirestore.instance
        .collection('user_roles')
        .doc(user.uid)
        .get();

    if (!roleDoc.exists ||
        roleDoc.data()?['role'] != 'resident') {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus ==
        AuthorizationStatus.denied) {
      return;
    }

    const androidSettings =
    fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = fln.DarwinInitializationSettings();

    const initializationSettings = fln.InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
    );

    const channel = fln.AndroidNotificationChannel(
      'visitor_alerts',
      'Visitor Alerts',
      description: 'Notifications when a visitor arrives',
      importance: fln.Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    Future<void> saveToken(String token) async {
      await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .doc(user.uid)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final token = await _messaging.getToken();

    if (token != null) {
      await saveToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null || currentUser.uid != user.uid) {
        return;
      }

      await saveToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;

      if (notification == null) return;

      await _localNotifications.show(
        id: message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch,
        title: notification.title ?? 'Society Connect',
        body: notification.body ?? 'A visitor has arrived.',
        notificationDetails: const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'visitor_alerts',
            'Visitor Alerts',
            channelDescription:
            'Notifications when a visitor arrives',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
          ),
          iOS: fln.DarwinNotificationDetails(),
        ),
      );
    });

    _initialized = true;
  }
}