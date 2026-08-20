import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._internal();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> init() async {
    if (_isInitialized || !isSupported) return;

    try {
      tz.initializeTimeZones();
      // LunaCare currently ships for users in Taiwan.
      tz.setLocalLocation(tz.getLocation('Asia/Taipei'));

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            debugPrint('通知 payload: ${details.payload}');
          }
        },
      );
      _isInitialized = true;
    } on Object catch (error) {
      _isInitialized = false;
      debugPrint('通知服務初始化失敗: $error');
    }
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    if (!_isInitialized) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> checkPermissions() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    if (!_isInitialized) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    // Apple platforms expose the system prompt through requestPermissions;
    // avoid showing it during a passive status check.
    return true;
  }

  Future<void> schedulePeriodReminders(
    DateTime nextPeriod,
    Set<int> reminderDays,
    TimeOfDay reminderTime,
  ) async {
    if (!isSupported) return;
    await _ensureInitialized();
    if (!_isInitialized) return;

    await cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final days in reminderDays) {
      final reminderDate = nextPeriod.subtract(Duration(days: days));
      final scheduledAt = tz.TZDateTime(
        tz.local,
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        reminderTime.hour,
        reminderTime.minute,
      );
      if (!scheduledAt.isAfter(now)) continue;

      await _notifications.zonedSchedule(
        100 + days,
        '經期提醒',
        _messageForDays(days),
        scheduledAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'period_channel',
            '經期提醒',
            channelDescription: '依照你的週期設定提醒預估經期日期',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'period_reminder_$days',
      );
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _ensureInitialized();
    if (_isInitialized) await _notifications.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!isSupported) return <PendingNotificationRequest>[];
    await _ensureInitialized();
    if (!_isInitialized) return <PendingNotificationRequest>[];
    return _notifications.pendingNotificationRequests();
  }

  Future<void> showTestNotification() async {
    if (!isSupported) return;
    await _ensureInitialized();
    if (!_isInitialized) return;

    await _notifications.show(
      999,
      'LunaCare 測試通知',
      '提醒功能已成功開啟。',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          '測試通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  String _messageForDays(int days) {
    if (days == 0) return '預估經期可能在今天開始';
    if (days == 1) return '預估經期可能在明天開始';
    return '預估經期可能在 $days 天後開始';
  }
}
