// lib/services/database_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_record.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static SharedPreferences? _prefs;
  static const String _dailyRecordsKey = 'daily_records';
  static const String _nextIdKey = 'next_id';
  static int _nextId = 0;

  DatabaseService._init();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    _nextId = _prefs!.getInt(_nextIdKey) ?? 0;
    return _prefs!;
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
      // 如果找不到記錄，檢查是否在經期內
      final isInPeriod = await this.isInPeriod(date);
      if (isInPeriod) {
        return DailyRecord(
          date: date,
          hasPeriod: true,
        );
      }
      return null;
    }
  }

  // 獲取所有經期日期
  Future<List<DateTime>> getAllPeriodDays() async {
    final records = await getAllDailyRecords();
    List<DateTime> periodDays = [];
    
    // 按日期排序
    records.sort((a, b) => a.date.compareTo(b.date));
    
    DateTime? periodStart;
    for (var record in records) {
      if (record.hasPeriod && periodStart == null) {
        // 找到經期開始
        periodStart = record.date;
      } else if (!record.hasPeriod && periodStart != null) {
        // 找到經期結束，添加這期間的所有日期
        var currentDate = periodStart;
        while (currentDate!.isBefore(record.date)) {
          periodDays.add(currentDate);
          currentDate = currentDate.add(const Duration(days: 1));
        }
        periodStart = null;
      }
    }

    // 如果有未結束的經期（最後一次標記為"是"但還沒有標記"否"）
    if (periodStart != null) {
      var currentDate = periodStart;
      var today = DateTime.now();
      while (!currentDate!.isAfter(today)) {
        periodDays.add(currentDate);
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    return periodDays;
  }

  // 檢查指定日期是否在經期內
  Future<bool> isInPeriod(DateTime date) async {
    final records = await getAllDailyRecords();
    records.sort((a, b) => a.date.compareTo(b.date));

    DateTime? periodStart;
    for (var record in records) {
      if (record.hasPeriod && periodStart == null) {
        periodStart = record.date;
      }
      if (!record.hasPeriod && periodStart != null) {
        if (date.isAfter(periodStart.subtract(const Duration(days: 1))) && 
            date.isBefore(record.date)) {
          return true;
        }
        periodStart = null;
      }
    }

    // 檢查是否在最後一個未結束的經期內
    if (periodStart != null) {
      return date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
             !date.isAfter(DateTime.now());
    }

    return false;
  }

  // 查找最後一次經期開始的日期
  Future<DateTime?> findLastPeriodStartDate() async {
    final records = await getAllDailyRecords();
    if (records.isEmpty) return null;

    // 按日期排序（新到舊）
    records.sort((a, b) => b.date.compareTo(a.date));
    
    // 找到最近一次經期開始的記錄
    var lastPeriodRecord = records.firstWhere(
      (record) => record.hasPeriod,
      orElse: () => records.first,
    );

    return lastPeriodRecord.date;
  }

  // 保存記錄
  Future<void> saveDailyRecord(DailyRecord record) async {
    final records = await getAllDailyRecords();
    final index = records.indexWhere((r) => isSameDay(r.date, record.date));

    if (index != -1) {
      // 更新現有記錄
      records[index] = record.copyWith(id: records[index].id);
    } else {
      // 添加新記錄
      final newRecord = record.copyWith(id: _nextId++);
      records.add(newRecord);
      
      // 保存新的 ID
      final pref = await prefs;
      await pref.setInt(_nextIdKey, _nextId);
    }

    await _saveDailyRecords(records);

    // 如果是標記經期結束，需要填充中間的日期
    if (!record.hasPeriod) {
      final periodStart = await findLastPeriodStartDate();
      if (periodStart != null && periodStart.isBefore(record.date)) {
        var currentDate = periodStart.add(const Duration(days: 1));
        while (currentDate.isBefore(record.date)) {
          // 檢查這一天是否已經有記錄
          final existingRecord = await getDailyRecord(currentDate);
          if (existingRecord == null) {
            // 為中間的每一天創建記錄
            final middleRecord = DailyRecord(
              date: currentDate,
              hasPeriod: true,
            );
            await _saveSingleRecord(middleRecord);
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }
  }

  // 保存單條記錄
  Future<void> _saveSingleRecord(DailyRecord record) async {
    final records = await getAllDailyRecords();
    final index = records.indexWhere((r) => isSameDay(r.date, record.date));

    if (index != -1) {
      records[index] = record.copyWith(id: records[index].id);
    } else {
      final newRecord = record.copyWith(id: _nextId++);
      records.add(newRecord);
      final pref = await prefs;
      await pref.setInt(_nextIdKey, _nextId);
    }

    await _saveDailyRecords(records);
  }

  // 保存所有記錄
  Future<void> _saveDailyRecords(List<DailyRecord> records) async {
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
    await _saveDailyRecords(records);
  }

  // 清除所有資料
  Future<void> clearAllData() async {
    final pref = await prefs;
    await pref.remove(_dailyRecordsKey);
    await pref.remove(_nextIdKey);
    _nextId = 0;
  }

  // 檢查兩個日期是否為同一天
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 獲取統計資訊
  Future<Map<String, dynamic>> getStatistics() async {
    final records = await getAllDailyRecords();
    if (records.isEmpty) {
      return {
        'averageCycleLength': 0,
        'averagePeriodLength': 0,
        'commonSymptoms': <String>[],
      };
    }

    // 找出所有經期週期
    List<List<DailyRecord>> periods = [];
    List<DailyRecord> currentPeriod = [];
    
    for (var record in records) {
      if (record.hasPeriod) {
        if (currentPeriod.isEmpty || 
            record.date.difference(currentPeriod.last.date).inDays <= 1) {
          currentPeriod.add(record);
        } else {
          if (currentPeriod.isNotEmpty) {
            periods.add(List.from(currentPeriod));
          }
          currentPeriod = [record];
        }
      }
    }
    if (currentPeriod.isNotEmpty) {
      periods.add(currentPeriod);
    }

    // 計算週期長度
    List<int> cycleLengths = [];
    for (int i = 0; i < periods.length - 1; i++) {
      final currentStart = periods[i].first.date;
      final nextStart = periods[i + 1].first.date;
      final cycleLength = currentStart.difference(nextStart).inDays.abs();
      if (cycleLength > 0 && cycleLength < 45) {  // 排除異常值
        cycleLengths.add(cycleLength);
      }
    }

    // 計算經期長度
    List<int> periodLengths = periods
        .map((period) => period.length)
        .where((length) => length > 0 && length < 15) // 排除異常值
        .toList();

    // 統計症狀
    Map<String, int> symptomCount = {};
    for (var record in records.where((r) => r.hasPeriod)) {
      record.symptoms.forEach((symptom, hasSymptom) {
        if (hasSymptom) {
          symptomCount[symptom] = (symptomCount[symptom] ?? 0) + 1;
        }
      });
    }

    // 找出最常見的症狀
    var commonSymptoms = symptomCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'averageCycleLength': cycleLengths.isEmpty 
        ? 0 
        : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length,
      'averagePeriodLength': periodLengths.isEmpty 
        ? 0 
        : periodLengths.reduce((a, b) => a + b) / periodLengths.length,
      'commonSymptoms': commonSymptoms
        .take(3)
        .map((e) => e.key)
        .toList(),
    };
  }
}