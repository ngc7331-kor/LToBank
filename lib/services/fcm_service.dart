import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 메시지 핸들러
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // 🛡️ 보안: 더 이상 서비스 계정 키를 코드에 직접 적지 않습니다.
  // 실제 데이터는 assets/secrets/service-account.json 에 저장되며, .gitignore로 보호됩니다.

  Future<void> initialize() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(settings: initSettings);

    const channel = AndroidNotificationChannel(
      'ltobank_channel',
      'L.To Bank 알림',
      description: 'L.To Bank 거래 승인 및 요청 알림입니다.',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/launcher_icon',
              largeIcon: const DrawableResourceAndroidBitmap('launcher_icon'),
              color: Color(0xFF0D47A1),
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;
    return await _fcm.getToken();
  }

  Future<String?> _getAccessToken() async {
    try {
      // 🛡️ 보안: 로컬 에셋 파일에서 비밀 키 로드
      final String jsonString = await rootBundle.loadString('assets/secrets/service-account.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(accountCredentials, scopes);
      final token = authClient.credentials.accessToken.data;
      authClient.close();
      return token;
    } catch (e) {
      debugPrint("❌ CRITICAL: Service Account Secret is missing or invalid! (Check assets/secrets/): $e");
      return null;
    }
  }

  Future<void> sendPushMessage({
    required String targetRoleOrName, 
    required String title, 
    required String body
  }) async {
    if (kIsWeb) return; 

    try {
      // 1. 타겟 유저의 FCM 토큰 조회
      final sysQuery = await FirebaseFirestore.instance.collection('users').get();
      String? targetToken;
      
      for (var doc in sysQuery.docs) {
        final data = doc.data();
        final email = data['email'] as String? ?? '';
        final role = data['role'] as String? ?? '';
        
        bool isMatch = false;
        if (targetRoleOrName == 'admin' && role == 'admin') {
          isMatch = true;
        } else if (targetRoleOrName == 'cw' && email.contains('cw')) {
          isMatch = true;
        } else if (targetRoleOrName == 'dk' && email.contains('dk')) {
          isMatch = true;
        }
        
        if (isMatch && data.containsKey('fcmToken')) {
          targetToken = data['fcmToken'];
          break;
        }
      }

      if (targetToken == null || targetToken.isEmpty) return;

      // 2. OAuth2 토큰 획득
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;
      
      // 3. 프로젝트 ID 로드 및 발송
      final String jsonString = await rootBundle.loadString('assets/secrets/service-account.json');
      final projectId = jsonDecode(jsonString)['project_id'];
      if (projectId == null) return;

      // 3. HTTP v1 API 호출 구현
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': targetToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'notification': {
                'icon': 'launcher_icon',
                'color': '#0D47A1',
                'notification_priority': 'PRIORITY_HIGH',
              }
            }
          }
        }),
      );
      
      if (response.statusCode != 200) {
        debugPrint('FCM Error: \${response.body}');
      }
    } catch (e) {
      debugPrint('FCM Exception: \$e');
    }
  }
}
