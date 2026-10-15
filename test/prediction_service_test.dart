import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/models/user_settings.dart';
import 'package:period_tracking/services/prediction_service.dart';

List<DailyRecord> _period(DateTime start, int days) => <DailyRecord>[
      for (var day = 0; day < days; day++)
        DailyRecord(
          date: DateTime(start.year, start.month, start.day + day),
          hasPeriod: true,
          bleedingLevel: BleedingLevel.medium,
        ),
    ];

void main() {
  final settings = UserSettings(cycleLength: 28, periodLength: 5);

  test('連續五天經期會被歸為同一次，而不是拆成 4+1 天', () {
    final records = <DailyRecord>[
      for (var day = 1; day <= 5; day++)
        DailyRecord(date: DateTime(2026, 1, day), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 2, 1), hasPeriod: true),
    ];

    final periods = PredictionService.findPeriodDetails(records);

    expect(periods, hasLength(2));
    expect(periods.first.$1, DateTime(2026, 1, 1));
    expect(periods.first.$2, 5);
    expect(periods.last.$1, DateTime(2026, 2, 1));
    expect(periods.last.$2, 1);
  });

  test('經期中漏記一天仍算同一次，週期不會被算成 14 天', () {
    final records = <DailyRecord>[
      for (final day in <int>[1, 2, 3, 5])
        DailyRecord(date: DateTime(2026, 1, day), hasPeriod: true),
      ..._period(DateTime(2026, 1, 29), 5),
    ];

    expect(
      PredictionService.findPeriodDetails(records),
      <(DateTime, int)>[(DateTime(2026, 1, 1), 5), (DateTime(2026, 1, 29), 5)],
    );

    final forecast = PredictionService.forecast(
      records,
      settings,
      today: DateTime(2026, 2, 3),
    )!;
    expect(forecast.cycleLength, 28);
    expect(forecast.nextStart, DateTime(2026, 2, 26));
  });

  test('只有點滴出血不算一次經期，經期前的點滴也不會讓開始日提前', () {
    final records = <DailyRecord>[
      ..._period(DateTime(2026, 1, 1), 5),
      DailyRecord(
        date: DateTime(2026, 1, 14),
        hasPeriod: true,
        bleedingLevel: BleedingLevel.spotting,
      ),
      DailyRecord(
        date: DateTime(2026, 1, 27),
        hasPeriod: true,
        bleedingLevel: BleedingLevel.spotting,
      ),
      ..._period(DateTime(2026, 1, 29), 4),
    ];

    expect(
      PredictionService.findPeriodDetails(records),
      <(DateTime, int)>[(DateTime(2026, 1, 1), 5), (DateTime(2026, 1, 29), 4)],
    );
  });

  test('不合理的間隔不算週期，並以最近週期的中位數預估', () {
    final starts = <DateTime>[
      DateTime(2025, 1, 1),
      DateTime(2025, 6, 1), // 151 天沒記錄，不是真的週期
      DateTime(2025, 6, 29),
      DateTime(2025, 7, 28),
      DateTime(2025, 9, 22), // 漏記一次，間隔 56 天
      DateTime(2025, 10, 20),
      DateTime(2025, 11, 16),
    ];
    final records = <DailyRecord>[
      for (final start in starts) ..._period(start, 4),
    ];

    final forecast = PredictionService.forecast(
      records,
      settings,
      today: DateTime(2025, 11, 20),
    )!;

    expect(forecast.cyclesUsed, 5);
    expect(forecast.cycleLength, 28);
    expect(forecast.nextStart, DateTime(2025, 12, 14));
  });

  test('超過預估日還沒有新經期時顯示延遲，不再列出已過的預估', () {
    final records = _period(DateTime(2026, 1, 1), 5);

    final forecast = PredictionService.forecast(
      records,
      settings,
      today: DateTime(2026, 2, 3),
    )!;

    expect(forecast.expectedStart, DateTime(2026, 1, 29));
    expect(forecast.isLate, isTrue);
    expect(forecast.daysLate, 5);
    expect(forecast.nextStart, isNull);
    expect(
      PredictionService.predictNextPeriods(
        records,
        settings,
        today: DateTime(2026, 2, 3),
      ),
      isEmpty,
    );
  });

  test('超過一整個週期沒記錄時，從今天往後推算並標示為舊資料', () {
    final records = _period(DateTime(2026, 1, 1), 5);

    final forecast = PredictionService.forecast(
      records,
      settings,
      today: DateTime(2026, 5, 1),
    )!;

    expect(forecast.isLate, isFalse);
    expect(forecast.isStale, isTrue);
    expect(forecast.nextStart, DateTime(2026, 5, 21));
  });

  test('沒有經期資料時不建立預測或誤差範圍', () {
    expect(
      PredictionService.predictNextPeriods(<DailyRecord>[], settings),
      isEmpty,
    );
    expect(PredictionService.forecast(<DailyRecord>[], settings), isNull);
    expect(PredictionService.predictionRangeDays(<DailyRecord>[]), isNull);
  });

  test('三次規律經期後依實際週期預估，誤差至少顯示 ±1 天', () {
    final records = <DailyRecord>[
      DailyRecord(date: DateTime(2026, 1, 1), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 1, 29), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 2, 26), hasPeriod: true),
    ];

    expect(PredictionService.predictionRangeDays(records), 1);
    expect(
      PredictionService.predictNextPeriods(
        records,
        settings,
        today: DateTime(2026, 3, 1),
      ).first,
      DateTime(2026, 3, 26),
    );
  });

  test('週期長短不一時，誤差範圍反映實際差距', () {
    final records = <DailyRecord>[
      DailyRecord(date: DateTime(2026, 1, 1), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 1, 27), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 2, 26), hasPeriod: true),
    ];

    expect(PredictionService.predictionRangeDays(records), 2);
    expect(
      PredictionService.predictionRangeDays(records.take(2).toList()),
      isNull,
    );
  });

  test('經期長度不計入可能還在進行中的這一次', () {
    final records = <DailyRecord>[
      ..._period(DateTime(2026, 1, 1), 5),
      ..._period(DateTime(2026, 1, 29), 5),
      ..._period(DateTime(2026, 2, 26), 2),
    ];

    final stats = PredictionService.getStatistics(
      records,
      settings,
      today: DateTime(2026, 2, 27),
    );

    expect(stats['periodLength'], 5);
    expect(stats['cycleLength'], 28);
  });

  test('平均疼痛只計算有評分的日子', () {
    final records = <DailyRecord>[
      DailyRecord(date: DateTime(2026, 1, 1), hasPeriod: true, painLevel: 6),
      DailyRecord(date: DateTime(2026, 1, 2), hasPeriod: true),
    ];

    final stats = PredictionService.getStatistics(records, settings);

    expect(stats['averagePainLevel'], '6.0');
  });

  test('常見症狀以記錄天數呈現，並顯示中文名稱', () {
    final records = <DailyRecord>[
      DailyRecord(
        date: DateTime(2026, 1, 1),
        symptoms: <String, bool>{'headache': true},
      ),
      DailyRecord(
        date: DateTime(2026, 1, 2),
        symptoms: <String, bool>{'headache': true},
      ),
    ];

    final stats = PredictionService.getStatistics(records, settings);

    expect(stats['commonSymptoms'], contains('頭痛（2 天）'));
  });
}
