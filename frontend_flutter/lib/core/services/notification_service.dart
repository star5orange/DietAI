import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 通知点击回调类型
/// reminderId: 提醒ID, reminderType: 提醒类型(water/meal等)
typedef NotificationTapCallback = void Function(
  int notificationId,
  String? payload,
);

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isAvailable => _initialized && !kIsWeb;

  /// 通知点击回调
  static NotificationTapCallback? onNotificationTapped;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'open');

      final settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
      _initialized = true;
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        'Notification tapped: id=${response.id}, payload=${response.payload}');
    // 调用全局回调
    if (onNotificationTapped != null && response.id != null) {
      onNotificationTapped!(response.id!, response.payload);
    }
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    List<int> repeatDays = const [],
    String? reminderType,
  }) async {
    if (!isAvailable) return;

    await cancelReminder(id);

    const androidDetails = AndroidNotificationDetails(
      'dietai_reminders',
      'DietAI 提醒',
      channelDescription: '饮食和健康提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      styleInformation: DefaultStyleInformation(true, true),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      if (repeatDays.isEmpty) {
        final now = tz.TZDateTime.now(tz.local);
        var scheduled =
            tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'reminder_${id}_${reminderType ?? 'unknown'}',
        );
      } else {
        for (final day in repeatDays) {
          var scheduled = _nextInstanceOfDay(hour, minute, day);
          await _plugin.zonedSchedule(
            id * 10 + day,
            title,
            body,
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'reminder_${id}_${reminderType ?? 'unknown'}_day$day',
          );
        }
      }
    } catch (e) {
      debugPrint('scheduleReminder error: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfDay(int hour, int minute, int weekday) {
    var scheduled = tz.TZDateTime.now(tz.local);
    scheduled = tz.TZDateTime(
        tz.local, scheduled.year, scheduled.month, scheduled.day, hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelReminder(int id) async {
    if (!isAvailable) return;
    try {
      await _plugin.cancel(id);
      for (int day = 1; day <= 7; day++) {
        await _plugin.cancel(id * 10 + day);
      }
    } catch (e) {
      debugPrint('cancelReminder error: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    if (!isAvailable) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAllReminders error: $e');
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!isAvailable) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'dietai_reminders',
        'DietAI 提醒',
        channelDescription: '饮食和健康提醒通知',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('showImmediateNotification error: $e');
    }
  }
}
