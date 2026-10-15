import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_record.dart';

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
  static const String _recoveryKeyPrefix = 'daily_records_recovery_';
  static const String _schemaVersionKey = 'daily_records_schema_version';

  /// Format of the stored records. 1 (no key saved): enums by index and
  /// symptoms by Chinese label. 2: enums by name and symptoms by ID. Both are
  /// readable; every save writes the current one.
  static const int _schemaVersion = 2;

  static SharedPreferences? _prefs;
  static int _nextId = 0;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Writes read the whole list, change it and save it back, so they run one
  /// at a time to keep a concurrent write from being lost.
  Future<void> _writeQueue = Future<void>.value();

  DatabaseService._init();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    _nextId = _prefs!.getInt(_nextIdKey) ?? 0;
    return _prefs!;
  }

  /// Returns every readable record, newest first.
  ///
  /// Records that can't be read are skipped, and the stored data is first
  /// copied to a recovery key. The next save then can't destroy the only copy.
  Future<List<DailyRecord>> getAllDailyRecords() async {
    final pref = await prefs;
    final recordsJson = pref.getString(_dailyRecordsKey);
    if (recordsJson == null || recordsJson.isEmpty) return <DailyRecord>[];
    // A newer app version may have saved fields this one would drop on the
    // next save, e.g. after a downgrade, so keep an untouched copy first.
    if ((pref.getInt(_schemaVersionKey) ?? 1) > _schemaVersion) {
      await _keepRecoveryCopy(pref, recordsJson);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(recordsJson);
    } on FormatException catch (error) {
      debugPrint('每日記錄無法解析: $error');
    }
    if (decoded is! List) {
      await _keepRecoveryCopy(pref, recordsJson);
      return <DailyRecord>[];
    }

    final records = <DailyRecord>[];
    var unreadable = 0;
    for (final value in decoded) {
      try {
        records.add(
          DailyRecord.fromJson(Map<String, dynamic>.from(value as Map)),
        );
      } on Object catch (error) {
        unreadable++;
        debugPrint('略過無法讀取的每日記錄: $error');
      }
    }
    if (unreadable > 0) await _keepRecoveryCopy(pref, recordsJson);
    return records..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<DailyRecord?> getDailyRecord(DateTime date) async {
    final records = await getAllDailyRecords();
    for (final record in records) {
      if (isSameDay(record.date, date)) return record;
    }
    return null;
  }

  Future<void> saveDailyRecord(DailyRecord record) =>
      saveDailyRecords(<DailyRecord>[record]);

  /// Saves several days with a single read and write, e.g. a period range.
  Future<void> saveDailyRecords(List<DailyRecord> newRecords) {
    return _serializedWrite(() async {
      if (newRecords.isEmpty) return;
      final records = await getAllDailyRecords();
      for (final record in newRecords) {
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
      }

      await _saveRecords(records);
      await (await prefs).setInt(_nextIdKey, _nextId);
      revision.value++;
    });
  }

  /// Replaces all records in one validated write. Used by backup restore.
  Future<void> replaceAllRecords(List<DailyRecord> records) {
    return _serializedWrite(() async {
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
    });
  }

  Future<void> deleteDailyRecord(DateTime date) {
    return _serializedWrite(() async {
      final records = await getAllDailyRecords();
      final originalLength = records.length;
      records.removeWhere((record) => isSameDay(record.date, date));
      if (records.length == originalLength) return;

      await _saveRecords(records);
      revision.value++;
    });
  }

  /// Deletes every record on the device, including recovery copies.
  Future<void> clearAllData() {
    return _serializedWrite(() async {
      final pref = await prefs;
      final recoveryKeys = pref
          .getKeys()
          .where((key) => key.startsWith(_recoveryKeyPrefix))
          .toList();
      for (final key in <String>[
        _dailyRecordsKey,
        _nextIdKey,
        _isInPeriodKey,
        _schemaVersionKey,
        ...recoveryKeys,
      ]) {
        await pref.remove(key);
      }
      _nextId = 0;
      revision.value++;
    });
  }

  Future<void> _saveRecords(List<DailyRecord> records) async {
    final sorted = List<DailyRecord>.from(records)
      ..sort((a, b) => b.date.compareTo(a.date));
    final pref = await prefs;
    final saved = await pref.setString(
      _dailyRecordsKey,
      jsonEncode(sorted.map((record) => record.toJson()).toList()),
    );
    if (!saved) throw StateError('無法儲存每日記錄');
    await pref.setInt(_schemaVersionKey, _schemaVersion);
  }

  Future<T> _serializedWrite<T>(Future<T> Function() write) {
    final result = _writeQueue.then((_) => write());
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _keepRecoveryCopy(SharedPreferences pref, String raw) async {
    final alreadyKept = pref.getKeys().any(
          (key) =>
              key.startsWith(_recoveryKeyPrefix) && pref.getString(key) == raw,
        );
    if (alreadyKept) return;
    await pref.setString(
      '$_recoveryKeyPrefix${DateTime.now().millisecondsSinceEpoch}',
      raw,
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _prefs = null;
    _nextId = 0;
    _writeQueue = Future<void>.value();
    revision.value = 0;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
