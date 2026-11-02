import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/services/period_range_service.dart';

void main() {
  DateTime nov(int day) => DateTime(2026, 11, day);

  DailyRecord periodDay(
    int day, {
    BleedingLevel level = BleedingLevel.medium,
    Map<String, bool>? symptoms,
    String? notes,
  }) =>
      DailyRecord(
        date: nov(day),
        hasPeriod: true,
        bleedingLevel: level,
        painLevel: 4,
        symptoms: symptoms,
        notes: notes,
      );

  Map<DateTime, DailyRecord> byDay(List<DailyRecord> records) =>
      <DateTime, DailyRecord>{
        for (final record in records) record.date: record
      };

  test('新增經期時，開始到結束的每一天都標記為經期', () {
    final change = PeriodRangeService.plan(
      const <DailyRecord>[],
      requested: PeriodRange(nov(10), nov(14)),
    );

    expect(change.range, PeriodRange(nov(10), nov(14)));
    expect(change.delete, isEmpty);
    expect(change.save.map((record) => record.date), <DateTime>[
      for (var day = 10; day <= 14; day++) nov(day),
    ]);
    expect(change.save.every((record) => record.hasPeriod), isTrue);
    expect(
      change.save.map((record) => record.bleedingLevel).toSet(),
      <BleedingLevel>{BleedingLevel.medium},
    );
  });

  test('已有記錄的日子保留原本的出血量和其他內容', () {
    final existing = <DailyRecord>[
      DailyRecord(date: nov(11), symptoms: <String, bool>{'headache': true}),
      periodDay(12, level: BleedingLevel.heavy),
    ];
    final change = PeriodRangeService.plan(
      existing,
      requested: PeriodRange(nov(11), nov(13)),
    );
    final saved = byDay(change.save);

    expect(saved[nov(11)]!.hasPeriod, isTrue);
    expect(saved[nov(11)]!.symptoms['headache'], isTrue);
    // Already a period day: nothing to change.
    expect(saved.containsKey(nov(12)), isFalse);
    expect(saved[nov(13)]!.hasPeriod, isTrue);
  });

  test('縮短經期時，移除的日子保留症狀與備註，空白的日子直接刪除', () {
    final existing = <DailyRecord>[
      for (var day = 10; day <= 12; day++) periodDay(day),
      periodDay(13, symptoms: <String, bool>{'fatigue': true}),
      periodDay(14),
    ];
    final change = PeriodRangeService.plan(
      existing,
      previous: PeriodRange(nov(10), nov(14)),
      requested: PeriodRange(nov(10), nov(12)),
    );

    expect(change.range, PeriodRange(nov(10), nov(12)));
    expect(change.delete, <DateTime>[nov(14)]);
    final kept = change.save.single;
    expect(kept.date, nov(13));
    expect(kept.hasPeriod, isFalse);
    expect(kept.bleedingLevel, isNull);
    expect(kept.painLevel, isNull);
    expect(kept.symptoms['fatigue'], isTrue);
  });

  test('延長經期只新增多出來的日子', () {
    final existing = <DailyRecord>[periodDay(10), periodDay(11)];
    final change = PeriodRangeService.plan(
      existing,
      previous: PeriodRange(nov(10), nov(11)),
      requested: PeriodRange(nov(10), nov(13)),
    );

    expect(change.delete, isEmpty);
    expect(change.save.map((record) => record.date), <DateTime>[
      nov(12),
      nov(13),
    ]);
  });

  test('刪除經期會移除每一天的經期標記', () {
    final existing = <DailyRecord>[
      periodDay(10),
      periodDay(11, notes: '肚子痛'),
      periodDay(12),
    ];
    final change = PeriodRangeService.plan(
      existing,
      previous: PeriodRange(nov(10), nov(12)),
    );

    expect(change.range, isNull);
    expect(change.delete, <DateTime>[nov(10), nov(12)]);
    expect(change.save.single.date, nov(11));
    expect(change.save.single.hasPeriod, isFalse);
    expect(change.save.single.notes, '肚子痛');
  });

  test('和相鄰經期只差兩天以內時合併，並補上中間的日子', () {
    final existing = <DailyRecord>[periodDay(1), periodDay(2)];
    final change = PeriodRangeService.plan(
      existing,
      requested: PeriodRange(nov(5), nov(6)),
    );

    expect(change.range, PeriodRange(nov(1), nov(6)));
    expect(
      change.save.map((record) => record.date),
      unorderedEquals(<DateTime>[nov(3), nov(4), nov(5), nov(6)]),
    );
  });

  test('相隔超過兩天的經期不合併', () {
    final existing = <DailyRecord>[periodDay(1), periodDay(2)];
    final change = PeriodRangeService.plan(
      existing,
      requested: PeriodRange(nov(6), nov(7)),
    );

    expect(change.range, PeriodRange(nov(6), nov(7)));
    expect(change.save, hasLength(2));
  });

  test('找出某天所在的經期時，和預估一樣容許中間漏記兩天', () {
    final records = <DailyRecord>[
      periodDay(1),
      periodDay(2),
      periodDay(5),
      periodDay(20),
    ];

    expect(
      PeriodRangeService.periodContaining(records, nov(3)),
      PeriodRange(nov(1), nov(5)),
    );
    expect(
      PeriodRangeService.periodContaining(records, nov(20)),
      PeriodRange(nov(20), nov(20)),
    );
    expect(PeriodRangeService.periodContaining(records, nov(10)), isNull);
  });

  test('結束日不能早於開始日', () {
    expect(() => PeriodRange(nov(5), nov(4)), throwsArgumentError);
  });
}
