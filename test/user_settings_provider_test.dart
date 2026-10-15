import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/providers/user_settings_provider.dart';
import 'package:period_tracking/services/database_service.dart';
import 'package:period_tracking/services/notification_service.dart';
import 'package:period_tracking/services/prediction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  final database = DatabaseService.instance;

  setUp(() async {
    calls.clear();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });
    NotificationService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notifications_enabled': true,
      'reminder_days': <String>['1'],
      'reminder_time': '9:0',
    });
    await database.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<DateTime> scheduledTimes() {
    return calls.where((call) => call.method == 'zonedSchedule').map((call) {
      final arguments = Map<String, Object?>.from(call.arguments as Map);
      expect(arguments['timeZoneName'], 'UTC');
      return DateTime.parse('${arguments['scheduledDateTime']}Z').toLocal();
    }).toList();
  }

  test('提醒排在畫面顯示的預估日前一天，新增記錄後會自動重排', () async {
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    DateTime nineOn(DateTime date) =>
        DateTime(date.year, date.month, date.day, 9);

    await database.saveDailyRecords(<DailyRecord>[
      for (var i = 0; i < 5; i++)
        DailyRecord(date: day(-15 + i), hasPeriod: true),
    ]);
    final provider = UserSettingsProvider();
    addTearDown(provider.dispose);
    await provider.ready;

    // One period so far, so the 28-day setting is used: next start is day 13.
    expect(scheduledTimes(), <DateTime>[nineOn(day(12))]);
    expect(provider.nextReminderAt, nineOn(day(12)));
    expect(provider.reminderError, isNull);

    calls.clear();
    await database.saveDailyRecords(<DailyRecord>[
      for (var i = 0; i < 5; i++)
        DailyRecord(date: day(-45 + i), hasPeriod: true),
    ]);
    await provider.reminderSyncDone;

    // The recorded 30-day cycle now wins, exactly as on the calendar.
    final forecast = PredictionService.forecast(
      await database.getAllDailyRecords(),
      provider.settings,
    )!;
    expect(forecast.nextStart, day(15));
    expect(scheduledTimes(), <DateTime>[nineOn(day(14))]);
    expect(provider.nextReminderAt, nineOn(day(14)));
  });

  test('排程失敗時在設定頁顯示簡短原因，而不是靜默失敗', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      throw PlatformException(
        code: 'error',
        message: 'Missing type parameter.',
        details: 'java.lang.RuntimeException: Missing type parameter.\n\tat …',
      );
    });
    final now = DateTime.now();
    await database.saveDailyRecords(<DailyRecord>[
      DailyRecord(
        date: DateTime(now.year, now.month, now.day - 3),
        hasPeriod: true,
      ),
    ]);

    final provider = UserSettingsProvider();
    addTearDown(provider.dispose);
    await provider.ready;

    expect(provider.reminderError, 'Missing type parameter.');
    expect(provider.nextReminderAt, isNull);
  });

  test('經期比預估晚時不排提醒，也不會用設定值硬算出新日期', () async {
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

    await database.saveDailyRecords(<DailyRecord>[
      for (var i = 0; i < 5; i++)
        DailyRecord(date: day(-33 + i), hasPeriod: true),
    ]);
    final provider = UserSettingsProvider();
    addTearDown(provider.dispose);
    await provider.ready;

    expect(scheduledTimes(), isEmpty);
    expect(provider.nextReminderAt, isNull);
  });
}
