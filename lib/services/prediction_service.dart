import 'dart:math' show max, sqrt;

import 'package:collection/collection.dart';

import '../models/daily_record.dart';
import '../models/user_settings.dart';
import '../utils/date_utils.dart';

/// The next-period estimate. The calendar, the analysis page and reminders all
/// read it from [PredictionService.forecast], so they never disagree.
class PeriodForecast {
  const PeriodForecast({
    required this.lastStart,
    required this.cycleLength,
    required this.periodLength,
    required this.cyclesUsed,
    required this.expectedStart,
    required this.daysLate,
    required this.isStale,
    required this.upcomingStarts,
  });

  /// Start of the most recent recorded period.
  final DateTime lastStart;

  /// Cycle length in days used for the estimate.
  final int cycleLength;

  /// Typical period length in days, used to shade predicted days.
  final int periodLength;

  /// Recorded cycles behind [cycleLength]; 0 means the settings value is used.
  final int cyclesUsed;

  /// [lastStart] plus one cycle. This may already be in the past.
  final DateTime expectedStart;

  /// Days past [expectedStart] without a new period; 0 when not late.
  final int daysLate;

  /// More than a whole cycle has passed since [expectedStart] without a new
  /// period, so [upcomingStarts] are only projected from old records.
  final bool isStale;

  /// Estimated starts from today on. Empty while the period is late, since the
  /// next start depends on when the late period actually begins.
  final List<DateTime> upcomingStarts;

  bool get isLate => daysLate > 0;

  DateTime? get nextStart =>
      upcomingStarts.isEmpty ? null : upcomingStarts.first;
}

class PredictionService {
  /// Unrecorded days allowed inside one period before it counts as two.
  static const int maxMissingDaysInPeriod = 2;

  /// Gaps outside this range are most likely missed records or bleeding that
  /// wasn't a period, so they are left out of cycle estimates.
  static const int minPlausibleCycleLength = 15;
  static const int maxPlausibleCycleLength = 90;

  /// Estimates follow the most recent cycles only.
  static const int recentCycleCount = 6;

  /// Groups recorded period days into periods.
  ///
  /// Up to [maxMissingDaysInPeriod] unrecorded days inside a period are
  /// treated as forgotten entries instead of splitting the period. Spotting
  /// before the first day of flow doesn't move the start, and spotting alone
  /// is not counted as a period.
  static List<(DateTime start, int length)> findPeriodDetails(
    List<DailyRecord> records,
  ) {
    final periodRecords = records.where((record) => record.hasPeriod).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final result = <(DateTime start, int length)>[];
    var group = <DailyRecord>[];
    for (final record in periodRecords) {
      if (group.isNotEmpty &&
          DateUtils.daysBetween(group.last.date, record.date) >
              maxMissingDaysInPeriod + 1) {
        _addPeriod(result, group);
        group = <DailyRecord>[];
      }
      group.add(record);
    }
    _addPeriod(result, group);
    return result;
  }

  static Map<String, dynamic> getStatistics(
    List<DailyRecord> records,
    UserSettings settings, {
    DateTime? today,
  }) {
    final periodDetails = findPeriodDetails(records);
    final cycleLengths = _recentCycleLengths(periodDetails);

    final symptomCounts = <String, int>{};
    var totalPain = 0;
    var painCount = 0;
    for (final record in records) {
      for (final entry in record.symptoms.entries) {
        if (entry.value) {
          symptomCounts[entry.key] = (symptomCounts[entry.key] ?? 0) + 1;
        }
      }
      if (record.painLevel != null) {
        totalPain += record.painLevel!;
        painCount++;
      }
    }

    final commonSymptoms = symptomCounts.entries
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5)
        .map((entry) => '${entry.key}（${entry.value} 天）')
        .toList();

    return <String, dynamic>{
      'cycleLength':
          cycleLengths.isEmpty ? settings.cycleLength : _median(cycleLengths),
      'periodLength': _typicalPeriodLength(
        periodDetails,
        settings,
        DateUtils.dateOnly(today ?? DateTime.now()),
      ),
      'cyclesUsed': cycleLengths.length,
      'cycleRegularity': cycleLengths.length >= 2
          ? _regularityForCycleLengths(cycleLengths)
          : null,
      'commonSymptoms': commonSymptoms,
      'averagePainLevel':
          painCount == 0 ? null : (totalPain / painCount).toStringAsFixed(1),
      'totalRecords': records.length,
      'totalPeriods': periodDetails.length,
      'isUsingSettings': cycleLengths.isEmpty,
      'lastPeriodStart': periodDetails.isEmpty ? null : periodDetails.last.$1,
    };
  }

  /// Estimates the next period from recorded periods; null without any.
  static PeriodForecast? forecast(
    List<DailyRecord> records,
    UserSettings settings, {
    DateTime? today,
  }) {
    final periodDetails = findPeriodDetails(records);
    if (periodDetails.isEmpty) return null;

    final currentDay = DateUtils.dateOnly(today ?? DateTime.now());
    final cycleLengths = _recentCycleLengths(periodDetails);
    final cycleLength =
        cycleLengths.isEmpty ? settings.cycleLength : _median(cycleLengths);
    final lastStart = periodDetails.last.$1;
    final expectedStart = DateUtils.addDays(lastStart, cycleLength);
    final overdueDays = DateUtils.daysBetween(expectedStart, currentDay);
    final isLate = overdueDays > 0 && overdueDays <= cycleLength;
    final isStale = overdueDays > cycleLength;

    // When stale, skip whole cycles up to the first start on or after today.
    final firstCycle = isStale
        ? (DateUtils.daysBetween(lastStart, currentDay) / cycleLength).ceil()
        : 1;

    return PeriodForecast(
      lastStart: lastStart,
      cycleLength: cycleLength,
      periodLength: _typicalPeriodLength(periodDetails, settings, currentDay),
      cyclesUsed: cycleLengths.length,
      expectedStart: expectedStart,
      daysLate: isLate ? overdueDays : 0,
      isStale: isStale,
      upcomingStarts: isLate
          ? const <DateTime>[]
          : <DateTime>[
              for (var index = 0; index < 3; index++)
                DateUtils.addDays(
                  lastStart,
                  cycleLength * (firstCycle + index),
                ),
            ],
    );
  }

  static List<DateTime> predictNextPeriods(
    List<DailyRecord> records,
    UserSettings settings, {
    DateTime? today,
  }) {
    return forecast(records, settings, today: today)?.upcomingStarts ??
        const <DateTime>[];
  }

  /// How many days actual starts usually land from the estimate (±), based on
  /// recent cycles. Null until at least two cycles are recorded.
  static int? predictionRangeDays(List<DailyRecord> records) {
    final cycleLengths = _recentCycleLengths(findPeriodDetails(records));
    if (cycleLengths.length < 2) return null;
    return max(1, _standardDeviation(cycleLengths).round());
  }

  static void _addPeriod(
    List<(DateTime start, int length)> periods,
    List<DailyRecord> group,
  ) {
    final firstFlow = group.firstWhereOrNull(
      (record) => record.bleedingLevel != BleedingLevel.spotting,
    );
    if (firstFlow == null) return;
    final start = DateUtils.dateOnly(firstFlow.date);
    periods.add((start, DateUtils.daysBetween(start, group.last.date) + 1));
  }

  /// Plausible gaps between recent period starts.
  static List<int> _recentCycleLengths(
    List<(DateTime start, int length)> periodDetails,
  ) {
    final lengths = <int>[
      for (var index = 1; index < periodDetails.length; index++)
        DateUtils.daysBetween(
          periodDetails[index - 1].$1,
          periodDetails[index].$1,
        ),
    ]
        .where(
          (days) =>
              days >= minPlausibleCycleLength &&
              days <= maxPlausibleCycleLength,
        )
        .toList();
    return lengths.length > recentCycleCount
        ? lengths.sublist(lengths.length - recentCycleCount)
        : lengths;
  }

  static int _typicalPeriodLength(
    List<(DateTime start, int length)> periodDetails,
    UserSettings settings,
    DateTime today,
  ) {
    var completed = periodDetails;
    if (completed.isNotEmpty) {
      final latest = completed.last;
      final latestDay = DateUtils.addDays(latest.$1, latest.$2 - 1);
      // The latest period may still be going on, so its length isn't final.
      if (DateUtils.daysBetween(latestDay, today) <=
          maxMissingDaysInPeriod + 1) {
        completed = completed.sublist(0, completed.length - 1);
      }
    }
    if (completed.isEmpty) return settings.periodLength;
    final recent = completed.length > recentCycleCount
        ? completed.sublist(completed.length - recentCycleCount)
        : completed;
    return _median(recent.map((period) => period.$2).toList());
  }

  /// The median ignores a single odd cycle, such as a month whose period
  /// wasn't recorded.
  static int _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  static double _standardDeviation(List<int> values) {
    final mean = values.average;
    final variance =
        values.map((value) => (value - mean) * (value - mean)).sum /
            values.length;
    return sqrt(variance);
  }

  static double _regularityForCycleLengths(List<int> cycleLengths) {
    final mean = cycleLengths.average;
    if (mean == 0) return 0;
    return (1 - (_standardDeviation(cycleLengths) / mean)).clamp(0.0, 1.0);
  }
}
