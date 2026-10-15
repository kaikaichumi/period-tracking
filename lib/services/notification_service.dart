import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// A reminder before an estimated period start, in the device's local time.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.daysBefore,
    required this.time,
  });

  final int id;
  final int daysBefore;
  final DateTime time;
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();

  static const Color _accentColor = Color(0xFFB33A6C);

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
      const settings = InitializationSettings(
        // Status bar icons must be single-colour; the launcher icon would show
        // up as a blank square.
        android: AndroidInitializationSettings('ic_stat_notification'),
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

  /// Works out when each reminder should fire, skipping times already past.
  static List<PlannedReminder> planPeriodReminders(
    DateTime nextPeriod,
    Set<int> reminderDays,
    TimeOfDay reminderTime, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final reminders = <PlannedReminder>[
      for (final days in reminderDays)
        PlannedReminder(
          id: 100 + days,
          daysBefore: days,
          time: DateTime(
            nextPeriod.year,
            nextPeriod.month,
            nextPeriod.day - days,
            reminderTime.hour,
            reminderTime.minute,
          ),
        ),
    ]..removeWhere((reminder) => !reminder.time.isAfter(currentTime));
    return reminders..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Replaces every scheduled reminder and returns the new ones, earliest
  /// first.
  Future<List<PlannedReminder>> schedulePeriodReminders(
    DateTime nextPeriod,
    Set<int> reminderDays,
    TimeOfDay reminderTime,
  ) async {
    if (!isSupported) return const <PlannedReminder>[];
    await _ensureInitialized();
    if (!_isInitialized) throw StateError('通知服務無法初始化');

    await _notifications.cancelAll();
    final reminders =
        planPeriodReminders(nextPeriod, reminderDays, reminderTime);
    for (final reminder in reminders) {
      await _notifications.zonedSchedule(
        reminder.id,
        '經期提醒',
        _messageForDays(reminder.daysBefore),
        // A UTC instant taken from the device's local time keeps reminders on
        // the user's own time zone without bundling a time zone database.
        tz.TZDateTime.from(reminder.time, tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'period_channel',
            '經期提醒',
            channelDescription: '依照你的週期設定提醒預估經期日期',
            importance: Importance.high,
            priority: Priority.high,
            color: _accentColor,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'period_reminder_${reminder.daysBefore}',
      );
    }
    return reminders;
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await _ensureInitialized();
    if (_isInitialized) await _notifications.cancelAll();
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
          color: _accentColor,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  @visibleForTesting
  void resetForTesting() => _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  String _messageForDays(int days) {
    if (days == 0) return '預估經期可能在今天開始';
    if (days == 1) return '預估經期可能在明天開始';
    return '預估經期可能在 $days 天後開始';
  }
}
