// lib/services/prediction_service.dart
import 'dart:math' show sqrt;
import 'package:collection/collection.dart';
import '../models/daily_record.dart';
import '../models/user_settings.dart';

class PredictionService {
  // 從記錄中找出所有經期開始日期和長度
  static List<(DateTime start, int length)> findPeriodDetails(List<DailyRecord> records) {
    List<(DateTime start, int length)> periodDetails = [];
    DateTime? currentStart;
    int currentLength = 0;
    
    // 確保記錄按日期排序(從舊到新)
    records.sort((a, b) => a.date.compareTo(b.date));
    
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      
      // 處理經期結束的情況（hasPeriod 為 false 但是最後一天）
      bool isLastDay = false;
      if (!record.hasPeriod && i > 0) {
        final previousRecord = records[i - 1];
        if (previousRecord.hasPeriod && 
            record.date.difference(previousRecord.date).inDays == 1) {
          isLastDay = true;
        }
      }
      
      if (record.hasPeriod || isLastDay) {
        if (currentStart == null) {
          currentStart = record.date;
          currentLength = 1;
        } else if (record.date.difference(currentStart).inDays <= 3 || isLastDay) {
          currentLength++;
        } else {
          if (currentLength > 0) {
            periodDetails.add((currentStart, currentLength));
          }
          currentStart = record.date;
          currentLength = 1;
        }
      } else if (currentStart != null && !isLastDay) {
        // 儲存當前週期並重置
        if (currentLength > 0) {
          periodDetails.add((currentStart, currentLength));
        }
        currentStart = null;
        currentLength = 0;
      }
    }
    
    // 處理最後一個週期
    if (currentStart != null && currentLength > 0) {
      periodDetails.add((currentStart, currentLength));
    }
    
    return periodDetails;
  }

  // 計算統計資訊
  static Map<String, dynamic> getStatistics(
    List<DailyRecord> records, 
    UserSettings settings,
  ) {
    if (records.isEmpty) {
      return {
        'averageCycleLength': settings.cycleLength,
        'averagePeriodLength': settings.periodLength,
        'cycleRegularity': 0.0,
        'commonSymptoms': <String>[],
        'averagePainLevel': '0.0',
        'totalRecords': 0,
        'totalPeriods': 0,
        'isUsingSettings': true,
        'lastPeriodStart': null,
      };
    }

    final periodDetails = findPeriodDetails(records);
    
    // 計算週期長度
    List<int> cycleLengths = [];
    for (int i = 0; i < periodDetails.length - 1; i++) {
      final days = periodDetails[i + 1].$1.difference(periodDetails[i].$1).inDays;
      cycleLengths.add(days);
    }

    // 計算平均週期長度
    final averageCycle = cycleLengths.isEmpty
        ? settings.cycleLength
        : (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();

    // 計算平均經期長度
    final periodLengths = periodDetails.map((p) => p.$2).toList();
    final averagePeriod = periodLengths.isEmpty
        ? settings.periodLength
        : (periodLengths.reduce((a, b) => a + b) / periodLengths.length).round();

    // 計算週期規律性
    double cycleRegularity = 0.0;
    if (cycleLengths.length >= 3) {
      final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
      final variance = cycleLengths
          .map((l) => pow(l - mean, 2))
          .reduce((a, b) => a + b) / cycleLengths.length;
      final stdDev = sqrt(variance);
      cycleRegularity = (1 - (stdDev / mean)).clamp(0.0, 1.0);
    }

    // 統計症狀
    Map<String, int> symptomCounts = {};
    double totalPain = 0;
    int painCount = 0;

    for (final record in records.where((r) => r.hasPeriod)) {
      record.symptoms.forEach((symptom, hasSymptom) {
        if (hasSymptom) {
          symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
        }
      });
      
      if (record.painLevel != null) {
        totalPain += record.painLevel!;
        painCount++;
      }
    }

    // 計算常見症狀
    final commonSymptoms = symptomCounts.entries
        .toList()
        .sorted((a, b) => b.value.compareTo(a.value))
        .take(5)
        .map((e) => "${e.key} (${(e.value / periodDetails.length * 100).round()}%)")
        .toList();

    return {
      'averageCycleLength': averageCycle,
      'averagePeriodLength': averagePeriod,
      'cycleRegularity': cycleRegularity,
      'commonSymptoms': commonSymptoms,
      'averagePainLevel': 
          painCount > 0 ? (totalPain / painCount).toStringAsFixed(1) : '0.0',
      'totalRecords': records.length,
      'totalPeriods': periodDetails.length,
      'isUsingSettings': periodDetails.length < 3,
      'lastPeriodStart': 
          periodDetails.isEmpty ? null : periodDetails.last.$1,
    };
  }

  // 預測接下來的經期
  static List<DateTime> predictNextPeriods(
    List<DailyRecord> records,
    UserSettings settings,
  ) {
    if (records.isEmpty) {
      // 如果沒有記錄，從今天開始預測
      final start = DateTime.now();
      return List.generate(3, (i) => start.add(
        Duration(days: settings.cycleLength * (i + 1))
      ));
    }

    final periodDetails = findPeriodDetails(records);
    
    // 計算週期長度
    List<int> cycleLengths = [];
    for (int i = 0; i < periodDetails.length - 1; i++) {
      final days = periodDetails[i + 1].$1.difference(periodDetails[i].$1).inDays;
      cycleLengths.add(days);
    }

    final cycleLength = cycleLengths.isEmpty || periodDetails.length < 3
        ? settings.cycleLength
        : (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();

    // 從最後一次經期開始預測
    final lastStart = periodDetails.isEmpty 
        ? DateTime.now() 
        : periodDetails.last.$1;
    
    return List.generate(3, (i) => lastStart.add(
      Duration(days: cycleLength * (i + 1))
    ));
  }

  // 根據週期規律性計算預測可信度(0-100)
  static int getPredictionConfidence(List<DailyRecord> records) {
    final periodDetails = findPeriodDetails(records);
    if (periodDetails.length < 3) return 50; // 資料不足時返回中等可信度

    // 計算週期規律性
    List<int> cycleLengths = [];
    for (int i = 0; i < periodDetails.length - 1; i++) {
      final days = periodDetails[i + 1].$1.difference(periodDetails[i].$1).inDays;
      cycleLengths.add(days);
    }

    if (cycleLengths.isEmpty) return 50;

    final mean = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    final variance = cycleLengths
        .map((l) => pow(l - mean, 2))
        .reduce((a, b) => a + b) / cycleLengths.length;
    final stdDev = sqrt(variance);
    final regularity = (1 - (stdDev / mean)).clamp(0.0, 1.0);

    // 將規律性轉換為可信度分數
    return (regularity * 100).round();
  }

  static double pow(double x, int exponent) {
    return x * x;  // 因為我們只需要平方，所以可以直接相乘
  }
}