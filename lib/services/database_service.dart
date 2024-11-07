// lib/services/database_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../models/daily_record.dart';
import '../services/prediction_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static SharedPreferences? _prefs;
  static const String _dailyRecordsKey = 'daily_records';
  static const String _nextIdKey = 'next_id';
  static const String _isInPeriodKey = 'is_in_period';  // 全域經期狀態
  static int _nextId = 0;

  DatabaseService._init();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    _nextId = _prefs!.getInt(_nextIdKey) ?? 0;
    return _prefs!;
  }

  // 儲存全域經期狀態
  Future<void> setInPeriod(bool isInPeriod) async {
    final pref = await prefs;
    await pref.setBool(_isInPeriodKey, isInPeriod);
  }

  // 讀取全域經期狀態
  Future<bool> getInPeriod() async {
    final pref = await prefs;
    return pref.getBool(_isInPeriodKey) ?? false;
  }

  // 獲取所有每日記錄
  Future<List<DailyRecord>> getAllDailyRecords() async {
    final pref = await prefs;
    final String? recordsJson = pref.getString(_dailyRecordsKey);
    if (recordsJson == null) return [];

    try {
      List<dynamic> recordsList = jsonDecode(recordsJson);
      var records = recordsList.map((json) => DailyRecord.fromJson(json)).toList();
      // 按日期排序（新到舊）
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    } catch (e) {
      print('Error decoding daily records: $e');
      return [];
    }
  }

  // 獲取指定日期的記錄
  Future<DailyRecord?> getDailyRecord(DateTime date) async {
    final records = await getAllDailyRecords();
    try {
      return records.firstWhere(
        (record) => isSameDay(record.date, date),
      );
    } catch (e) {
      return null;
    }
  }

// 找到指定日期之前最近的經期開始日期
Future<DateTime?> findPeriodStartBeforeDate(DateTime currentDate) async {
  final records = await getAllDailyRecords();
  if (records.isEmpty) return null;

  // 只取當前日期之前或當天的記錄
  final previousRecords = records.where(
    (r) => r.date.isBefore(currentDate) || isSameDay(r.date, currentDate)
  ).toList();

  // 按日期排序（新到舊）
  previousRecords.sort((a, b) => b.date.compareTo(a.date));

  // 找到最近的經期記錄
  final lastPeriodRecord = previousRecords.firstWhereOrNull((r) => r.hasPeriod);
  if (lastPeriodRecord == null) return null;

  // 從這個經期記錄往前找到開始日期
  var startDate = lastPeriodRecord.date;
  var checkDate = startDate;

  while (true) {
    final previousDay = checkDate.subtract(const Duration(days: 1));
    final previousRecord = previousRecords.firstWhereOrNull(
      (r) => isSameDay(r.date, previousDay)
    );

    if (previousRecord == null || !previousRecord.hasPeriod) {
      // 找到開始日期了
      break;
    }
    checkDate = previousDay;
  }

  return checkDate;
}

  // 保存記錄
  Future<void> saveDailyRecord(DailyRecord record) async {
    final records = await getAllDailyRecords();

    if (!record.hasPeriod) {
      // 如果是結束經期，需要先找到開始日期
      final periodStart = await findPeriodStartBeforeDate(record.date);
      if (periodStart != null && !isSameDay(periodStart, record.date)) {
        // 填補從開始日期到結束日期之間的所有日期
        var currentDate = periodStart;
        while (!currentDate.isAfter(record.date)) {
          final existingRecord = records.firstWhereOrNull(
            (r) => isSameDay(r.date, currentDate)
          );
          
          if (existingRecord == null) {
            // 如果日期不存在，創建新記錄
            final newRecord = DailyRecord(
              id: _nextId++,
              date: currentDate,
              hasPeriod: true,
              // 最後一天使用輕度出血，其他天使用中度
              bleedingLevel: isSameDay(currentDate, record.date) 
                ? BleedingLevel.light 
                : BleedingLevel.medium,
              // 如果是最後一天，設置經痛程度為1
              painLevel: isSameDay(currentDate, record.date) ? 0 : null,
              // 最後一天也標記為經期結束
              isPeriodEndDay: isSameDay(currentDate, record.date),
            );
            records.add(newRecord);
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
        
        final pref = await prefs;
        await pref.setInt(_nextIdKey, _nextId);
      }
    }

    // 如果是結束日，確保記錄包含必要資訊
    if (!record.hasPeriod && await isInPeriod(record.date)) {
      record = record.copyWith(
        bleedingLevel: BleedingLevel.light,
        painLevel: 0,
        isPeriodEndDay: true,
      );
    }

    // 儲存當前記錄
    final index = records.indexWhere((r) => isSameDay(r.date, record.date));
    if (index != -1) {
      records[index] = record.copyWith(id: records[index].id);
    } else {
      final newRecord = record.copyWith(id: _nextId++);
      records.add(newRecord);
      
      final pref = await prefs;
      await pref.setInt(_nextIdKey, _nextId);
    }

    await _saveRecords(records);
  }
  // 保存所有記錄
  Future<void> _saveRecords(List<DailyRecord> records) async {
    final pref = await prefs;
    final recordsJson = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    await pref.setString(_dailyRecordsKey, recordsJson);
  }

  // 刪除日記錄
  Future<void> deleteDailyRecord(DateTime date) async {
    final records = await getAllDailyRecords();
    records.removeWhere((record) => isSameDay(record.date, date));
    await _saveRecords(records);
    
    // 檢查並更新全域經期狀態
    final hasActivePeriod = records.any((r) => r.hasPeriod);
    if (!hasActivePeriod) {
      await setInPeriod(false);
    }
  }

  // 清除所有資料
  Future<void> clearAllData() async {
    final pref = await prefs;
    await pref.remove(_dailyRecordsKey);
    await pref.remove(_nextIdKey);
    await pref.remove(_isInPeriodKey);  // 清除經期狀態
    _nextId = 0;
  }

  // 檢查兩個日期是否為同一天
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 獲取所有經期日期
  Future<List<DateTime>> getAllPeriodDays() async {
    final records = await getAllDailyRecords();
    final periodDetails = PredictionService.findPeriodDetails(records);
    
    List<DateTime> periodDays = [];
    for (var period in periodDetails) {
      for (int i = 0; i < period.$2; i++) {
        periodDays.add(period.$1.add(Duration(days: i)));
      }
    }
    
    return periodDays;
  }

  // 檢查日期是否在經期內
  Future<bool> isInPeriod(DateTime date) async {
  // 找到該日期之前最近的經期開始
  final periodStart = await findPeriodStartBeforeDate(date);
  if (periodStart == null) return false;

  // 找到經期開始之後的第一個非經期記錄（結束記錄）
  final records = await getAllDailyRecords();
  final endRecord = records.firstWhereOrNull((r) => 
    !r.hasPeriod && 
    r.date.isAfter(periodStart) &&
    (r.date.isBefore(date) || isSameDay(r.date, date))
  );

  // 如果找到結束記錄，表示這段經期已結束
  if (endRecord != null) return false;

  // 如果沒有找到結束記錄，且當前日期在經期開始之後或當天，則表示在經期中
  return !date.isBefore(periodStart);
}

  // 更新全域經期狀態
  Future<void> _updateGlobalPeriodState() async {
    final records = await getAllDailyRecords();
    bool hasActivePeriod = false;
    
    // 找出所有經期段
    List<(DateTime start, DateTime? end)> periodRanges = [];
    DateTime? currentStart;
    
    // 按日期排序（舊到新）
    records.sort((a, b) => a.date.compareTo(b.date));
    
    for (final record in records) {
      if (record.hasPeriod) {
        if (currentStart == null) {
          currentStart = record.date;
        }
      } else {
        if (currentStart != null) {
          periodRanges.add((currentStart, record.date));
          currentStart = null;
        }
      }
    }
    
    // 處理仍在進行中的經期
    if (currentStart != null) {
      periodRanges.add((currentStart, null));
      hasActivePeriod = true;
    }

    // 更新全域狀態
    await setInPeriod(hasActivePeriod);
  }
  // 檢查指定日期是否位於任一經期區間內
  Future<bool> isInPeriodRange(DateTime date) async {
    final records = await getAllDailyRecords();
    
    // 找到日期最接近的經期記錄
    final nearestRecords = records.where((r) => 
      r.hasPeriod && r.date.difference(date).inDays.abs() <= 7
    ).toList();
    
    if (nearestRecords.isEmpty) return false;
    
    // 檢查是否在任一經期區間內
    return nearestRecords.any((r) => isSameDay(r.date, date));
  }

  // 檢查指定日期之後是否有經期結束記錄
Future<bool> hasEndRecordAfter(DateTime startDate) async {
  final records = await getAllDailyRecords();
  return records.any((record) => 
    !record.hasPeriod && 
    record.date.isAfter(startDate)
  );
}

// 尋找最後一次經期開始日期
Future<DateTime?> findLastPeriodStartDate() async {
  final records = await getAllDailyRecords();
  if (records.isEmpty) return null;

  // 按日期排序（新到舊）
  records.sort((a, b) => b.date.compareTo(a.date));
  
  for (var record in records) {
    if (record.hasPeriod) {
      final previousDay = record.date.subtract(const Duration(days: 1));
      final previousRecord = records.firstWhereOrNull(
        (r) => isSameDay(r.date, previousDay)
      );
      
      // 如果前一天不是經期，這天就是開始日
      if (previousRecord == null || !previousRecord.hasPeriod) {
        return record.date;
      }
    }
  }
  
  return null;
}


}