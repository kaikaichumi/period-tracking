import 'package:collection/collection.dart';

import '../models/daily_record.dart';
import '../utils/date_utils.dart';
import 'prediction_service.dart';

/// Consecutive period days as shown on the calendar, both ends included.
class PeriodRange {
  PeriodRange(DateTime start, DateTime end)
      : start = DateUtils.dateOnly(start),
        end = DateUtils.dateOnly(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('A period cannot end before it starts');
    }
  }

  final DateTime start;
  final DateTime end;

  int get length => DateUtils.daysBetween(start, end) + 1;

  Iterable<DateTime> get days sync* {
    for (var offset = 0; offset < length; offset++) {
      yield DateUtils.addDays(start, offset);
    }
  }

  bool contains(DateTime day) {
    final date = DateUtils.dateOnly(day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PeriodRange($start – $end)';
}

/// The record changes that give a period new dates.
class PeriodRangeChange {
  const PeriodRangeChange({
    required this.range,
    required this.save,
    required this.delete,
  });

  /// The period afterwards, including neighbouring periods it merged with;
  /// null when the period was removed.
  final PeriodRange? range;

  final List<DailyRecord> save;

  /// Days whose records are left with nothing in them.
  final List<DateTime> delete;

  bool get isEmpty => save.isEmpty && delete.isEmpty;
}

class PeriodRangeService {
  /// Flow for days marked from a date range; the daily record sheet starts
  /// from the same level.
  static const BleedingLevel defaultBleedingLevel = BleedingLevel.medium;

  /// Recorded periods, oldest first, grouped the same way as predictions.
  static List<PeriodRange> periods(List<DailyRecord> records) => <PeriodRange>[
        for (final group in PredictionService.groupPeriodDays(records))
          PeriodRange(group.first.date, group.last.date),
      ];

  static PeriodRange? periodContaining(
    List<DailyRecord> records,
    DateTime day,
  ) =>
      periods(records).firstWhereOrNull((period) => period.contains(day));

  /// Works out the changes that make [requested] a period, replacing
  /// [previous] when an existing period is being edited. Without [requested],
  /// [previous] is removed.
  ///
  /// Days taken out of a period keep their symptoms, notes and intimacy
  /// records; days left empty are deleted. A period that ends up within
  /// [PredictionService.maxMissingDaysInPeriod] days of another one counts as
  /// the same period, so the days between them are filled in too.
  static PeriodRangeChange plan(
    List<DailyRecord> records, {
    PeriodRange? previous,
    PeriodRange? requested,
  }) {
    final recordsByDay = <DateTime, DailyRecord>{
      for (final record in records) DateUtils.dateOnly(record.date): record,
    };
    // A null value means the day's record is deleted.
    final changes = <DateTime, DailyRecord?>{};

    for (final day in previous?.days ?? const <DateTime>[]) {
      final record = recordsByDay[day];
      if (requested?.contains(day) ?? false) continue;
      if (record == null || !record.hasPeriod) continue;
      final cleared = _withoutPeriod(record);
      changes[day] = _isEmpty(cleared) ? null : cleared;
    }

    if (requested == null) return _toChange(null, changes);

    DailyRecord? current(DateTime day) =>
        changes.containsKey(day) ? changes[day] : recordsByDay[day];

    final afterChanges = <DailyRecord>[
      for (final day in <DateTime>{...recordsByDay.keys, ...changes.keys})
        if (current(day) case final record?) record,
      for (final day in requested.days)
        if (!(current(day)?.hasPeriod ?? false))
          DailyRecord(date: day, hasPeriod: true),
    ];
    final merged = periodContaining(afterChanges, requested.start)!;

    for (final day in merged.days) {
      final record = current(day);
      if (record?.hasPeriod ?? false) continue;
      changes[day] = record == null
          ? DailyRecord(
              date: day,
              hasPeriod: true,
              bleedingLevel: defaultBleedingLevel,
            )
          : record.copyWith(
              hasPeriod: true,
              bleedingLevel: record.bleedingLevel ?? defaultBleedingLevel,
            );
    }
    return _toChange(merged, changes);
  }

  static PeriodRangeChange _toChange(
    PeriodRange? range,
    Map<DateTime, DailyRecord?> changes,
  ) {
    return PeriodRangeChange(
      range: range,
      save: <DailyRecord>[
        for (final record in changes.values)
          if (record != null) record,
      ],
      delete: <DateTime>[
        for (final entry in changes.entries)
          if (entry.value == null) entry.key,
      ],
    );
  }

  /// The daily record sheet only keeps flow and pain on period days.
  static DailyRecord _withoutPeriod(DailyRecord record) {
    return DailyRecord(
      id: record.id,
      date: record.date,
      symptoms: Map<String, bool>.from(record.symptoms),
      hasIntimacy: record.hasIntimacy,
      intimacyFrequency: record.intimacyFrequency,
      contraceptionMethod: record.contraceptionMethod,
      notes: record.notes,
      intimacyNotes: record.intimacyNotes,
    );
  }

  static bool _isEmpty(DailyRecord record) {
    return !record.hasPeriod &&
        !record.hasIntimacy &&
        !record.symptoms.values.any((value) => value) &&
        (record.notes?.trim().isEmpty ?? true) &&
        (record.intimacyNotes?.trim().isEmpty ?? true);
  }
}
