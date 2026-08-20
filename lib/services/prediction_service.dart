import 'dart:math' show sqrt;

import 'package:collection/collection.dart';

import '../models/daily_record.dart';
import '../models/user_settings.dart';

class PredictionService {
  /// Groups explicit, consecutive period days into period occurrences.
  static List<(DateTime start, int length)> findPeriodDetails(
    List<DailyRecord> records,
  ) {
    final periodRecords = records.where((record) => record.hasPeriod).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final result = <(DateTime start, int length)>[];
    DateTime? start;
    DateTime? previousDate;
    var length = 0;

    for (final record in periodRecords) {
      final date =
          DateTime(record.date.year, record.date.month, record.date.day);
      if (previousDate != null && date == previousDate) continue;

      final isConsecutive =
          previousDate != null && date.difference(previousDate).inDays == 1;
      if (start == null || !isConsecutive) {
        if (start != null) result.add((start, length));
        start = date;
        length = 1;
      } else {
        length++;
      }
      previousDate = date;
    }

    if (start != null) result.add((start, length));
    return result;
  }

  static Map<String, dynamic> getStatistics(
    List<DailyRecord> records,
    UserSettings settings,
  ) {
    final periodDetails = findPeriodDetails(records);
    final cycleLengths = _cycleLengths(periodDetails);
    final hasEnoughCycleData = cycleLengths.length >= 2;

    final averageCycle = cycleLengths.isEmpty
        ? settings.cycleLength
        : (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();
    final periodLengths = periodDetails.map((period) => period.$2).toList();
    final averagePeriod = periodLengths.isEmpty
        ? settings.periodLength
        : (periodLengths.reduce((a, b) => a + b) / periodLengths.length)
            .round();

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
      'averageCycleLength': averageCycle,
      'averagePeriodLength': averagePeriod,
      'cycleRegularity':
          hasEnoughCycleData ? _regularityForCycleLengths(cycleLengths) : null,
      'commonSymptoms': commonSymptoms,
      'averagePainLevel':
          painCount == 0 ? null : (totalPain / painCount).toStringAsFixed(1),
      'totalRecords': records.length,
      'totalPeriods': periodDetails.length,
      'isUsingSettings': cycleLengths.isEmpty,
      'hasEnoughCycleData': hasEnoughCycleData,
      'lastPeriodStart': periodDetails.isEmpty ? null : periodDetails.last.$1,
    };
  }

  static List<DateTime> predictNextPeriods(
    List<DailyRecord> records,
    UserSettings settings,
  ) {
    final periodDetails = findPeriodDetails(records);
    if (periodDetails.isEmpty) return <DateTime>[];

    final cycleLengths = _cycleLengths(periodDetails);
    final cycleLength = cycleLengths.isEmpty
        ? settings.cycleLength
        : (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();
    final lastStart = periodDetails.last.$1;
    return List<DateTime>.generate(
      3,
      (index) => lastStart.add(Duration(days: cycleLength * (index + 1))),
    );
  }

  /// Returns null until at least three period starts are available.
  static int? getPredictionConfidence(List<DailyRecord> records) {
    final cycleLengths = _cycleLengths(findPeriodDetails(records));
    if (cycleLengths.length < 2) return null;
    return (_regularityForCycleLengths(cycleLengths) * 100).round();
  }

  static List<int> _cycleLengths(
    List<(DateTime start, int length)> periodDetails,
  ) {
    final lengths = <int>[];
    for (var index = 0; index < periodDetails.length - 1; index++) {
      final days = periodDetails[index + 1]
          .$1
          .difference(periodDetails[index].$1)
          .inDays;
      if (days > 0) lengths.add(days);
    }
    return lengths;
  }

  static double _regularityForCycleLengths(List<int> cycleLengths) {
    final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    if (mean == 0) return 0;
    final variance = cycleLengths
            .map((length) => (length - mean) * (length - mean))
            .reduce((a, b) => a + b) /
        cycleLengths.length;
    return (1 - (sqrt(variance) / mean)).clamp(0.0, 1.0);
  }
}
