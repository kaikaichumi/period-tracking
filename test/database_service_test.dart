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

  test('儲存非經期日記不會自動補出中間的經期日期', () async {
    await database.saveDailyRecord(
      DailyRecord(date: DateTime(2026, 1, 1), hasPeriod: true),
    );
    await database.saveDailyRecord(
      DailyRecord(
        date: DateTime(2026, 1, 5),
        symptoms: <String, bool>{'頭痛': true},
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
}
