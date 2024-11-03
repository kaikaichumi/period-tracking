// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    // Android 設定
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 設定
    final IOSInitializationSettings iosSettings = IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );
    
    // 初始化設定
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // 初始化通知插件
    await _notifications.initialize(
      initSettings,
      onSelectNotification: onSelectNotification,
    );
  }

  Future onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    debugPrint('收到本地通知');
  }

  Future onSelectNotification(String? payload) async {
    if (payload != null) {
      debugPrint('通知payload: $payload');
    }
  }

  Future<void> schedulePeriodReminder(DateTime nextPeriod) async {
    final scheduledDate = nextPeriod.subtract(const Duration(days: 1));
    
    final androidDetails = AndroidNotificationDetails(
      'period_channel',
      '經期提醒',
      channelDescription: '月經週期追蹤提醒',
      importance: Importance.high,
      priority: Priority.high,
    );

    final iosDetails = IOSNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      0,
      '經期提醒',
      '您的下一次經期預計明天開始',
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // 取消所有通知
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // 檢查通知權限
  Future<bool> requestPermissions() async {
    final platform = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final result = await platform.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }
    return false;
  }

  // 發送即時通知
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'instant_channel',
      '即時通知',
      channelDescription: '即時通知頻道',
      importance: Importance.high,
      priority: Priority.high,
    );

    final iosDetails = IOSNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      details,
    );
  }
}