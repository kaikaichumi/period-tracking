import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/services/backup_service.dart';

List<int> _encode(Map<String, Object?> data) => utf8.encode(jsonEncode(data));

void main() {
  final validSettings = <String, Object?>{
    'cycleLength': 28,
    'periodLength': 5,
    'notificationsEnabled': false,
    'reminderTime': '9:0',
    'reminderDays': <int>[1],
  };
  final record = DailyRecord(date: DateTime(2025, 2, 1), hasPeriod: true);

  test('可以讀取舊版（1.0.0）格式的備份', () {
    final parsed = BackupService.parseBackup(
      _encode(<String, Object?>{
        'version': '1.0.0',
        'backup_date': '2025-03-01T10:00:00.000',
        'records': <Object>[record.toJson()],
        'settings': <String, Object?>{
          ...validSettings,
          'reminderDays': <int>[7, 3, 1, 0],
        },
      }),
    );

    expect(parsed.records, hasLength(1));
    expect(parsed.backupDate, DateTime(2025, 3, 1, 10));
  });

  test('沒有任何記錄的備份不能拿來還原', () {
    expect(
      () => BackupService.parseBackup(
        _encode(<String, Object?>{
          'records': <Object>[],
          'settings': validSettings,
        }),
      ),
      throwsFormatException,
    );
  });

  test('設定超出範圍的備份會被拒絕', () {
    expect(
      () => BackupService.parseBackup(
        _encode(<String, Object?>{
          'records': <Object>[record.toJson()],
          'settings': <String, Object?>{...validSettings, 'cycleLength': 40},
        }),
      ),
      throwsFormatException,
    );
  });

  test('錯誤訊息不會帶出 Exception: 前綴', () {
    expect(
      '${const BackupException('備份失敗：未登入 Google 帳號')}',
      '備份失敗：未登入 Google 帳號',
    );
  });
}
