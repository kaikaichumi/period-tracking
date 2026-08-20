import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_record.dart';
import 'prediction_service.dart';

/// Stores one explicit record per calendar day.
///
/// A non-period record must never be interpreted as "the end of a period" or
/// cause missing dates to be filled automatically. Users can record symptoms
/// and intimacy on any day without changing their menstrual history.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();

  static const String _dailyRecordsKey = 'daily_records';
  static const String _nextIdKey = 'next_id';
  static const String _isInPeriodKey = 'is_in_period';

  static SharedPreferences? _prefs;
  static int _nextId = 0;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  DatabaseService._init();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    _nextId = _prefs!.getInt(_nextIdKey) ?? 0;
    return _prefs!;
  }

  Future<List<DailyRecord>> getAllDailyRecords() async {
    final pref = await prefs;
    final recordsJson = pref.getString(_dailyRecordsKey);
    if (recordsJson == null || recordsJson.isEmpty) return <DailyRecord>[];

    try {
      final decoded = jsonDecode(recordsJson);
      if (decoded is! List) return <DailyRecord>[];

      final records = decoded
          .map(
            (json) => DailyRecord.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return records;
    } on Object catch (error) {
      debugPrint('讀取每日記錄失敗: $error');
      return <DailyRecord>[];
    }
  }

  Future<DailyRecord?> getDailyRecord(DateTime date) async {
    final records = await getAllDailyRecords();
    for (final record in records) {
      if (isSameDay(record.date, date)) return record;
    }
    return null;
  }

  Future<void> saveDailyRecord(DailyRecord record) async {
    final records = await getAllDailyRecords();
    final normalizedRecord = record.copyWith(date: _dateOnly(record.date));
    final index = records.indexWhere(
      (item) => isSameDay(item.date, normalizedRecord.date),
    );

    if (index >= 0) {
      records[index] = normalizedRecord.copyWith(id: records[index].id);
    } else {
      records.add(normalizedRecord.copyWith(id: _nextId));
      _nextId++;
    }

    await _saveRecords(records);
    await (await prefs).setInt(_nextIdKey, _nextId);
    revision.value++;
  }

  /// Replaces all records in one validated write. Used by backup restore.
  Future<void> replaceAllRecords(List<DailyRecord> records) async {
    final normalized = <DailyRecord>[];
    final seenDates = <String>{};

    for (final record in records) {
      final date = _dateOnly(record.date);
      final key = _dateKey(date);
      if (!seenDates.add(key)) {
        throw const FormatException('備份中包含重複日期');
      }
      normalized.add(record.copyWith(id: normalized.length, date: date));
    }

    _nextId = normalized.length;
    await _saveRecords(normalized);
    final pref = await prefs;
    await pref.setInt(_nextIdKey, _nextId);
    await pref.remove(_isInPeriodKey);
    revision.value++;
  }

  Future<void> deleteDailyRecord(DateTime date) async {
    final records = await getAllDailyRecords();
    final originalLength = records.length;
    records.removeWhere((record) => isSameDay(record.date, date));
    if (records.length == originalLength) return;

    await _saveRecords(records);
    revision.value++;
  }

  Future<void> clearAllData() async {
    final pref = await prefs;
    await pref.remove(_dailyRecordsKey);
    await pref.remove(_nextIdKey);
    await pref.remove(_isInPeriodKey);
    _nextId = 0;
    revision.value++;
  }

  Future<void> _saveRecords(List<DailyRecord> records) async {
    final sorted = List<DailyRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));
    final saved = await (await prefs).setString(
      _dailyRecordsKey,
      jsonEncode(sorted.map((record) => record.toJson()).toList()),
    );
    if (!saved) throw StateError('無法儲存每日記錄');
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<DateTime?> findPeriodStartBeforeDate(DateTime currentDate) async {
    final periods = PredictionService.findPeriodDetails(
      await getAllDailyRecords(),
    );
    DateTime? result;
    for (final period in periods) {
      if (!period.$1.isAfter(currentDate)) result = period.$1;
    }
    return result;
  }

  Future<DateTime?> findLastPeriodStartDate() async {
    final periods = PredictionService.findPeriodDetails(
      await getAllDailyRecords(),
    );
    return periods.isEmpty ? null : periods.last.$1;
  }

  Future<List<DateTime>> getAllPeriodDays() async {
    final records = await getAllDailyRecords();
    return records
        .where((record) => record.hasPeriod)
        .map((record) => _dateOnly(record.date))
        .toList();
  }

  Future<bool> isInPeriod(DateTime date) async {
    return (await getDailyRecord(date))?.hasPeriod ?? false;
  }

  Future<bool> isInPeriodRange(DateTime date) => isInPeriod(date);

  Future<bool> hasEndRecordAfter(DateTime startDate) async {
    final records = await getAllDailyRecords();
    return records.any(
      (record) => record.isPeriodEndDay && record.date.isAfter(startDate),
    );
  }

  // Kept for compatibility with data written by older versions.
  Future<void> setInPeriod(bool isInPeriod) async {
    await (await prefs).setBool(_isInPeriodKey, isInPeriod);
  }

  Future<bool> getInPeriod() async {
    final records = await getAllDailyRecords();
    if (records.isEmpty) return false;
    return records.first.hasPeriod && !records.first.isPeriodEndDay;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _prefs = null;
    _nextId = 0;
    revision.value = 0;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
