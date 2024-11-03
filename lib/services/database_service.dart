// lib/services/database_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/period_record.dart';
import '../models/intimacy_record.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static SharedPreferences? _prefs;
  static const String _dailyRecordsKey = 'daily_records';
  static const String _intimacyRecordsKey = 'intimacy_records';
  static int _nextId = 0;

  DatabaseService._init();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    _nextId = _prefs!.getInt('next_id') ?? 0;
    return _prefs!;
  }

  // 獲取所有經期記錄
  Future<List<PeriodRecord>> getAllPeriods() async {
    final pref = await prefs;
    final String? recordsJson = pref.getString(_dailyRecordsKey);
    if (recordsJson == null) return [];

    try {
      List<dynamic> recordsList = jsonDecode(recordsJson);
      return recordsList.map((json) => PeriodRecord.fromJson(json)).toList();
    } catch (e) {
      print('Error decoding period records: $e');
      return [];
    }
  }

  // 獲取所有親密關係記錄
  Future<List<IntimacyRecord>> getAllIntimacyRecords() async {
    final pref = await prefs;
    final String? recordsJson = pref.getString(_intimacyRecordsKey);
    if (recordsJson == null) return [];

    try {
      List<dynamic> recordsList = jsonDecode(recordsJson);
      return recordsList.map((json) => IntimacyRecord.fromJson(json)).toList();
    } catch (e) {
      print('Error decoding intimacy records: $e');
      return [];
    }
  }

  // 獲取指定日期的經期記錄
  Future<PeriodRecord?> getPeriodRecordForDate(DateTime date) async {
    final records = await getAllPeriods();
    try {
      return records.firstWhere(
        (record) => _isDateInPeriod(date, record),
      );
    } catch (e) {
      return null;
    }
  }

  // 獲取指定日期的親密關係記錄
  Future<IntimacyRecord?> getIntimacyRecordForDate(DateTime date) async {
    final records = await getAllIntimacyRecords();
    try {
      return records.firstWhere(
        (record) => 
          record.date.year == date.year && 
          record.date.month == date.month && 
          record.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  // 檢查日期是否在經期內
  bool _isDateInPeriod(DateTime date, PeriodRecord record) {
    if (record.endDate == null) {
      return date.year == record.startDate.year &&
             date.month == record.startDate.month &&
             date.day == record.startDate.day;
    }
    return date.isAfter(record.startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(record.endDate!.add(const Duration(days: 1)));
  }

  // 保存經期記錄
  Future<void> savePeriodRecord(PeriodRecord record) async {
    final records = await getAllPeriods();
    
    if (record.id != null) {
      final index = records.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        records[index] = record;
      } else {
        records.add(record);
      }
    } else {
      final newRecord = PeriodRecord(
        id: _nextId,
        startDate: record.startDate,
        endDate: record.endDate,
        painLevel: record.painLevel,
        symptoms: record.symptoms,
        flowIntensity: record.flowIntensity,
        notes: record.notes,
      );
      records.add(newRecord);
      _nextId++;
      await _saveNextId();
    }

    await _savePeriodRecords(records);
  }

  // 保存親密關係記錄
  Future<void> saveIntimacyRecord(IntimacyRecord record) async {
    final records = await getAllIntimacyRecords();
    final existingIndex = records.indexWhere((r) => 
      r.date.year == record.date.year && 
      r.date.month == record.date.month && 
      r.date.day == record.date.day
    );

    if (existingIndex != -1) {
      // 更新現有記錄
      records[existingIndex] = record;
    } else {
      // 添加新記錄
      records.add(record);
    }

    await _saveIntimacyRecords(records);
  }
  // 新增經期記錄
  Future<void> insertPeriod(PeriodRecord record) async {
    final records = await getAllPeriods();
    final newRecord = record.copyWith(id: _nextId++);
    records.add(newRecord);
    await _savePeriodRecords(records);
    
    // 保存新的 ID
    final pref = await prefs;
    await pref.setInt('next_id', _nextId);
  }

  // 更新經期記錄
  Future<void> updatePeriod(PeriodRecord record) async {
    final records = await getAllPeriods();
    final index = records.indexWhere((r) => r.id == record.id);
    if (index != -1) {
      records[index] = record;
      await _savePeriodRecords(records);
    }
  }

  // 刪除經期記錄
  Future<void> deletePeriodRecord(int id) async {
    final records = await getAllPeriods();
    records.removeWhere((record) => record.id == id);
    await _savePeriodRecords(records);
  }

  // 刪除親密關係記錄
  Future<void> deleteIntimacyRecord(int id) async {
    final records = await getAllIntimacyRecords();
    records.removeWhere((record) => record.id == id);
    await _saveIntimacyRecords(records);
  }

  // 保存下一個ID
  Future<void> _saveNextId() async {
    final pref = await prefs;
    await pref.setInt('next_id', _nextId);
  }

  // 保存經期記錄
  Future<void> _savePeriodRecords(List<PeriodRecord> records) async {
    final pref = await prefs;
    final recordsJson = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    await pref.setString(_dailyRecordsKey, recordsJson);
  }

  // 保存親密關係記錄
  Future<void> _saveIntimacyRecords(List<IntimacyRecord> records) async {
    final pref = await prefs;
    final recordsJson = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    await pref.setString(_intimacyRecordsKey, recordsJson);
  }
}