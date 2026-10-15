import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = DatabaseService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await database.resetForTesting();
  });

  Future<List<String?>> recoveryCopies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((key) => key.startsWith('daily_records_recovery_'))
        .map(prefs.getString)
        .toList();
  }

  test('儲存非經期日記不會自動補出中間的經期日期', () async {
    await database.saveDailyRecord(
      DailyRecord(date: DateTime(2026, 1, 1), hasPeriod: true),
    );
    await database.saveDailyRecord(
      DailyRecord(
        date: DateTime(2026, 1, 5),
        symptoms: <String, bool>{'headache': true},
      ),
    );

    final records = await database.getAllDailyRecords();

    expect(records, hasLength(2));
    expect(
      records.where((record) => record.hasPeriod).map((record) => record.date),
      <DateTime>[DateTime(2026, 1, 1)],
    );
    expect(await database.getDailyRecord(DateTime(2026, 1, 3)), isNull);
  });

  test('同一天再次儲存會更新原記錄，不會建立重複資料', () async {
    await database.saveDailyRecord(DailyRecord(date: DateTime(2026, 3, 3)));
    await database.saveDailyRecord(
      DailyRecord(date: DateTime(2026, 3, 3), hasPeriod: true),
    );

    final records = await database.getAllDailyRecords();
    expect(records, hasLength(1));
    expect(records.single.hasPeriod, isTrue);
  });

  test('有重複日期的備份會在覆蓋現有資料前被拒絕', () async {
    final original = DailyRecord(date: DateTime(2026, 4, 1), hasPeriod: true);
    await database.saveDailyRecord(original);

    await expectLater(
      database.replaceAllRecords(<DailyRecord>[
        DailyRecord(date: DateTime(2026, 5, 1)),
        DailyRecord(date: DateTime(2026, 5, 1)),
      ]),
      throwsFormatException,
    );

    final records = await database.getAllDailyRecords();
    expect(records, hasLength(1));
    expect(records.single.date, DateTime(2026, 4, 1));
  });

  test('一次儲存多天只寫入一次、只通知一次', () async {
    var notifications = 0;
    void listener() => notifications++;
    database.revision.addListener(listener);
    addTearDown(() => database.revision.removeListener(listener));

    await database.saveDailyRecords(<DailyRecord>[
      for (var day = 1; day <= 5; day++)
        DailyRecord(date: DateTime(2026, 7, day), hasPeriod: true),
    ]);

    expect(notifications, 1);
    expect(await database.getAllDailyRecords(), hasLength(5));
  });

  test('同時儲存兩天時，兩筆都會保留', () async {
    await Future.wait(<Future<void>>[
      database.saveDailyRecord(
        DailyRecord(date: DateTime(2026, 8, 1), hasPeriod: true),
      ),
      database.saveDailyRecord(
        DailyRecord(date: DateTime(2026, 8, 2), hasPeriod: true),
      ),
    ]);

    expect(await database.getAllDailyRecords(), hasLength(2));
  });

  test('整份資料無法解析時先保留原始內容，之後儲存也不會讓它消失', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_records': '{not json',
    });
    await database.resetForTesting();

    expect(await database.getAllDailyRecords(), isEmpty);
    await database.saveDailyRecord(
      DailyRecord(date: DateTime(2026, 6, 1), hasPeriod: true),
    );

    expect(await recoveryCopies(), <String>['{not json']);
    expect(await database.getAllDailyRecords(), hasLength(1));
  });

  test('舊版存的資料照常讀取，下次儲存時整份改成新格式', () async {
    final legacy = jsonEncode(<Object>[
      <String, Object?>{
        'id': 0,
        'date': '2025-05-01T00:00:00.000',
        'hasPeriod': true,
        'bleedingLevel': 4,
        'painLevel': 5,
        'symptoms': <String, bool>{'頭痛': true, '腹脹': false},
        'hasIntimacy': false,
        'intimacyFrequency': null,
        'contraceptionMethod': null,
        'notes': '舊資料',
        'intimacyNotes': null,
        'isPeriodEndDay': false,
      },
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_records': legacy,
      'next_id': 1,
    });
    await database.resetForTesting();

    final before = await database.getAllDailyRecords();
    expect(before.single.bleedingLevel, BleedingLevel.heavy);
    expect(before.single.symptoms['headache'], isTrue);

    await database.saveDailyRecord(DailyRecord(date: DateTime(2025, 5, 2)));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('daily_records_schema_version'), 2);
    final stored = (jsonDecode(prefs.getString('daily_records')!) as List)
        .cast<Map<String, dynamic>>();
    final migrated =
        stored.singleWhere((json) => json['date'] == '2025-05-01T00:00:00.000');
    expect(migrated['bleedingLevel'], 'heavy');
    expect(migrated['symptoms'], <String, dynamic>{
      'headache': true,
      'bloating': false,
    });
    expect(migrated['notes'], '舊資料');
    expect(await recoveryCopies(), isEmpty);
  });

  test('較新版本存的資料會先另存一份，避免被這個版本覆蓋掉', () async {
    final raw = jsonEncode(<Object>[
      DailyRecord(date: DateTime(2026, 6, 1), hasPeriod: true).toJson(),
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_records': raw,
      'daily_records_schema_version': 3,
    });
    await database.resetForTesting();

    expect(await database.getAllDailyRecords(), hasLength(1));
    expect(await recoveryCopies(), <String>[raw]);
  });

  test('刪除所有記錄時，復原用的副本也一起刪掉', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_records': '{not json',
    });
    await database.resetForTesting();
    await database.getAllDailyRecords();
    expect(await recoveryCopies(), hasLength(1));

    await database.clearAllData();

    final prefs = await SharedPreferences.getInstance();
    expect(await recoveryCopies(), isEmpty);
    expect(prefs.getString('daily_records'), isNull);
    expect(prefs.getInt('daily_records_schema_version'), isNull);
  });

  test('單筆記錄壞掉時只略過那一筆，原始資料另存一份', () async {
    final raw = jsonEncode(<Object>[
      DailyRecord(date: DateTime(2026, 6, 1), hasPeriod: true).toJson(),
      <String, Object?>{
        'date': '2026-06-02T00:00:00.000',
        'hasPeriod': true,
        'bleedingLevel': 99,
      },
    ]);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daily_records': raw,
    });
    await database.resetForTesting();

    final records = await database.getAllDailyRecords();
    expect(records.map((record) => record.date), <DateTime>[
      DateTime(2026, 6, 1),
    ]);

    await database.saveDailyRecord(DailyRecord(date: DateTime(2026, 6, 3)));

    expect(await recoveryCopies(), <String>[raw]);
    expect(await database.getAllDailyRecords(), hasLength(2));
  });
}
