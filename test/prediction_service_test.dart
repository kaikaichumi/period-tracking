import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/models/user_settings.dart';
import 'package:period_tracking/services/prediction_service.dart';

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

  test('沒有經期資料時不建立預測或假可信度', () {
    expect(
      PredictionService.predictNextPeriods(<DailyRecord>[], settings),
      isEmpty,
    );
    expect(
      PredictionService.getPredictionConfidence(<DailyRecord>[]),
      isNull,
    );
  });

  test('三次規律經期後才計算可信度', () {
    final records = <DailyRecord>[
      DailyRecord(date: DateTime(2026, 1, 1), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 1, 29), hasPeriod: true),
      DailyRecord(date: DateTime(2026, 2, 26), hasPeriod: true),
    ];

    expect(PredictionService.getPredictionConfidence(records), 100);
    expect(
      PredictionService.predictNextPeriods(records, settings).first,
      DateTime(2026, 3, 26),
    );
  });

  test('常見症狀以記錄天數呈現，不會產生超過 100% 的比例', () {
    final records = <DailyRecord>[
      DailyRecord(
        date: DateTime(2026, 1, 1),
        symptoms: <String, bool>{'頭痛': true},
      ),
      DailyRecord(
        date: DateTime(2026, 1, 2),
        symptoms: <String, bool>{'頭痛': true},
      ),
    ];

    final stats = PredictionService.getStatistics(records, settings);

    expect(stats['commonSymptoms'], contains('頭痛（2 天）'));
  });
}
