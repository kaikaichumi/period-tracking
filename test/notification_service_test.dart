import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iOS 通知權限', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <String>[];
    var enabled = false;

    setUp(() {
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      NotificationService.instance.resetForTesting();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'initialize' => true,
          'checkPermissions' => <String, bool>{'isEnabled': enabled},
          _ => null,
        };
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      NotificationService.instance.resetForTesting();
      debugDefaultTargetPlatformOverride = null;
    });

    test('檢查權限時讀取系統設定，不會跳出詢問視窗', () async {
      enabled = false;
      expect(await NotificationService.instance.checkPermissions(), isFalse);

      enabled = true;
      expect(await NotificationService.instance.checkPermissions(), isTrue);

      expect(calls, contains('checkPermissions'));
      expect(calls, isNot(contains('requestPermissions')));
    });
  });

  test('提醒依裝置當地時間排在經期前幾天，已過的時間會略過', () {
    final reminders = NotificationService.planPeriodReminders(
      DateTime(2026, 10, 20),
      <int>{0, 1, 3, 7},
      const TimeOfDay(hour: 9, minute: 30),
      now: DateTime(2026, 10, 15, 10),
    );

    expect(reminders.map((reminder) => reminder.time), <DateTime>[
      DateTime(2026, 10, 17, 9, 30),
      DateTime(2026, 10, 19, 9, 30),
      DateTime(2026, 10, 20, 9, 30),
    ]);
    expect(reminders.map((reminder) => reminder.id), <int>[103, 101, 100]);
  });

  test('提醒日跨月時日期正確', () {
    final reminders = NotificationService.planPeriodReminders(
      DateTime(2026, 11, 1),
      <int>{3},
      const TimeOfDay(hour: 8, minute: 0),
      now: DateTime(2026, 10, 1),
    );

    expect(reminders.single.time, DateTime(2026, 10, 29, 8));
  });
}
