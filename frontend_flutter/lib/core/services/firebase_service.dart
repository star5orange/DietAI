import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'api_service.dart';
import 'notification_service.dart';

/// Firebase / FCM 推送服务
///
/// 职责：
/// 1. 初始化 Firebase
/// 2. 请求通知权限
/// 3. 获取 FCM device token 并上传到后端
/// 4. 处理前台收到的 FCM 消息（显示本地通知）
/// 5. 处理通知点击（跳转/记录响应）
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  factory FirebaseService() => _instance;
  FirebaseService._();

  bool _initialized = false;
  bool get isAvailable => _initialized && !kIsWeb;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// 消息点击回调（供外部注册导航逻辑）
  static void Function(RemoteMessage message)? onMessageOpened;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final messaging = FirebaseMessaging.instance;

      // 请求通知权限
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('Firebase: 通知权限已授权');

        // 获取并上传 FCM token
        _fcmToken = await messaging.getToken();
        debugPrint('Firebase: FCM token = $_fcmToken');

        if (_fcmToken != null) {
          await _uploadTokenToBackend(_fcmToken!);
        }

        // 监听 token 刷新
        messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          debugPrint('Firebase: FCM token 已刷新');
          _uploadTokenToBackend(newToken);
        });

        // 通知点击（App 后台/关闭时点击通知）
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          debugPrint('Firebase: 消息被点击, data=${message.data}');
          _handleNotificationTap(message);
          onMessageOpened?.call(message);
        });

        // 冷启动通知
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('Firebase: 冷启动消息, data=${initialMessage.data}');
          _handleNotificationTap(initialMessage);
          onMessageOpened?.call(initialMessage);
        }

        // 前台消息：通过本地通知显示
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('Firebase: 前台消息, title=${message.notification?.title}');
          _showLocalNotification(message);
        });
      } else {
        debugPrint('Firebase: 通知权限被拒绝');
      }

      _initialized = true;
    } catch (e) {
      debugPrint('FirebaseService initialize error: $e');
      _initialized = true;
    }
  }

  /// 上传 FCM token 到后端
  Future<void> _uploadTokenToBackend(String token) async {
    try {
      final apiService = ApiService();
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS || Platform.isMacOS
              ? 'ios'
              : null;

      final response = await apiService.post(
        '/notifications/device-token',
        data: {
          'token': token,
          if (platform != null) 'platform': platform,
        },
      );

      if (response.success) {
        debugPrint('Firebase: device token 上传成功');
      } else {
        debugPrint('Firebase: device token 上传失败: ${response.message}');
      }
    } catch (e) {
      debugPrint('Firebase: 上传 device token 异常: $e');
    }
  }

  /// 处理通知点击 - 仅对喝水/吃饭提醒记录响应
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final reminderIdStr = data['reminder_id'] ?? '';
    final reminderId = int.tryParse(reminderIdStr);
    final reminderType = data['reminder_type'] ?? '';

    if (reminderId == null || reminderType.isEmpty) return;

    String? actionType;
    switch (reminderType) {
      case 'water':
        actionType = 'drank';
        break;
      case 'meal':
        actionType = 'ate';
        break;
      // pet_health / health_report 不需要记录响应
      default:
        return;
    }

    if (actionType == null) return;

    final api = ApiService();
    api.post('/notifications/responses', data: {
      'reminder_id': reminderId,
      'action_type': actionType,
    }).catchError((e) {
      debugPrint('Firebase: 记录通知响应失败: $e');
    });
  }

  /// 前台收到的 FCM 消息 → 显示为本地通知
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    try {
      NotificationService().showImmediateNotification(
        id: notification.hashCode,
        title: notification.title ?? 'DietAI 提醒',
        body: notification.body ?? '',
      );
    } catch (e) {
      debugPrint('Firebase: 显示本地通知失败: $e');
    }
  }
}
