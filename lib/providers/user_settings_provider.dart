import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_settings.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/prediction_service.dart';
import '../utils/constants.dart';

class UserSettingsProvider extends ChangeNotifier {
  int _cycleLength = AppConstants.defaultCycleLength;
  int _periodLength = AppConstants.defaultPeriodLength;
  bool _notificationsEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _reminderDays = <int>{1};

  late final Future<void> _loaded;
  Future<void>? _reminderSync;
  bool _reminderSyncRequested = false;
  bool _mayHaveScheduledReminders = false;
  DateTime? _nextReminderAt;
  String? _reminderError;
  bool _isDisposed = false;

  UserSettingsProvider() {
    // The next estimated start depends on the records, so reminders are
    // planned again whenever a record changes.
    DatabaseService.instance.revision.addListener(_syncReminders);
    _loaded = _loadSettings();
  }

  /// Completes once saved settings are loaded and reminders are planned.
  Future<void> get ready => _loaded;

  /// Completes when the reminder sync in progress, if any, has finished.
  @visibleForTesting
  Future<void> get reminderSyncDone => _reminderSync ?? Future<void>.value();

  int get cycleLength => _cycleLength;
  int get periodLength => _periodLength;
  bool get notificationsEnabled => _notificationsEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  Set<int> get reminderDays => Set<int>.unmodifiable(_reminderDays);

  /// When the earliest scheduled reminder fires, if any.
  DateTime? get nextReminderAt => _nextReminderAt;

  /// Why reminders couldn't be scheduled, shown in settings.
  String? get reminderError => _reminderError;

  UserSettings get settings => UserSettings(
        cycleLength: _cycleLength,
        periodLength: _periodLength,
        notificationsEnabled: _notificationsEnabled,
        reminderTime: _reminderTime,
        reminderDays: Set<int>.from(_reminderDays),
      );

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cycleLength = _validCycleLength(
        prefs.getInt(AppConstants.prefsCycleLength),
      );
      _periodLength = _validPeriodLength(
        prefs.getInt(AppConstants.prefsPeriodLength),
      );
      _notificationsEnabled =
          prefs.getBool(AppConstants.prefsNotificationsEnabled) ?? false;
      _reminderTime = _parseTime(
        prefs.getString(AppConstants.prefsReminderTime),
        fallback: const TimeOfDay(hour: 9, minute: 0),
      );
      _reminderDays = _parseReminderDays(
        prefs.getStringList(AppConstants.prefsReminderDays),
      );
    } on Object catch (error) {
      debugPrint('讀取設定失敗，已使用預設值: $error');
    } finally {
      _notify();
    }

    await _syncReminders();
  }

  Future<void> updateCycleLength(int newLength) async {
    if (newLength < AppConstants.minCycleLength ||
        newLength > AppConstants.maxCycleLength) {
      throw ArgumentError.value(newLength, 'newLength', '週期長度超出範圍');
    }
    _cycleLength = newLength;
    await _saveSettings();
  }

  Future<void> updatePeriodLength(int newLength) async {
    if (newLength < AppConstants.minPeriodLength ||
        newLength > AppConstants.maxPeriodLength) {
      throw ArgumentError.value(newLength, 'newLength', '經期長度超出範圍');
    }
    _periodLength = newLength;
    await _saveSettings();
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _saveSettings();
  }

  Future<void> updateReminderTime(TimeOfDay newTime) async {
    _reminderTime = newTime;
    await _saveSettings();
  }

  Future<void> updateReminderDays(Set<int> days) async {
    if (!days.every(AppConstants.reminderDayOptions.contains)) {
      throw ArgumentError.value(days, 'days', '包含不支援的提醒日');
    }
    _reminderDays = Set<int>.from(days);
    await _saveSettings();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cycleLength': _cycleLength,
        'periodLength': _periodLength,
        'notificationsEnabled': _notificationsEnabled,
        'reminderTime': '${_reminderTime.hour}:${_reminderTime.minute}',
        'reminderDays': _reminderDays.toList()..sort(),
      };

  Future<void> fromJson(Map<String, dynamic> json) async {
    final cycleLength = json['cycleLength'];
    final periodLength = json['periodLength'];
    final notificationsEnabled = json['notificationsEnabled'];
    final reminderTime = json['reminderTime'];
    final reminderDays = json['reminderDays'];

    if (cycleLength is! int ||
        cycleLength < AppConstants.minCycleLength ||
        cycleLength > AppConstants.maxCycleLength ||
        periodLength is! int ||
        periodLength < AppConstants.minPeriodLength ||
        periodLength > AppConstants.maxPeriodLength ||
        notificationsEnabled is! bool ||
        reminderTime is! String ||
        reminderDays is! List) {
      throw const FormatException('備份中的設定格式不正確');
    }

    final parsedDays = reminderDays.map((value) {
      if (value is! int) throw const FormatException('提醒日期格式不正確');
      return value;
    }).toSet();
    if (!parsedDays.every(AppConstants.reminderDayOptions.contains)) {
      throw const FormatException('備份中包含不支援的提醒日期');
    }

    final parsedTime = _parseTime(reminderTime, throwOnInvalid: true);
    _cycleLength = cycleLength;
    _periodLength = periodLength;
    _notificationsEnabled = notificationsEnabled;
    _reminderTime = parsedTime;
    _reminderDays = parsedDays;
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    _cycleLength = AppConstants.defaultCycleLength;
    _periodLength = AppConstants.defaultPeriodLength;
    _notificationsEnabled = false;
    _reminderTime = const TimeOfDay(hour: 9, minute: 0);
    _reminderDays = <int>{1};
    await _saveSettings();
  }

  @override
  void dispose() {
    _isDisposed = true;
    DatabaseService.instance.revision.removeListener(_syncReminders);
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefsCycleLength, _cycleLength);
    await prefs.setInt(AppConstants.prefsPeriodLength, _periodLength);
    await prefs.setBool(
      AppConstants.prefsNotificationsEnabled,
      _notificationsEnabled,
    );
    await prefs.setString(
      AppConstants.prefsReminderTime,
      '${_reminderTime.hour}:${_reminderTime.minute}',
    );
    await prefs.setStringList(
      AppConstants.prefsReminderDays,
      _reminderDays.map((day) => day.toString()).toList(),
    );
    _notify();
    await _syncReminders();
  }

  /// Plans reminders again from the latest records and settings. A request
  /// that arrives while a sync is running is folded into one more pass, and
  /// the returned future completes after that pass.
  Future<void> _syncReminders() {
    if (_reminderSync != null) {
      _reminderSyncRequested = true;
      return _reminderSync!;
    }
    return _reminderSync = _runReminderSync();
  }

  Future<void> _runReminderSync() async {
    try {
      do {
        _reminderSyncRequested = false;
        await _applyReminders();
      } while (_reminderSyncRequested && !_isDisposed);
    } finally {
      _reminderSync = null;
    }
  }

  Future<void> _applyReminders() async {
    final notifications = NotificationService.instance;
    if (!notifications.isSupported) return;

    try {
      DateTime? nextStart;
      if (_notificationsEnabled) {
        final records = await DatabaseService.instance.getAllDailyRecords();
        nextStart = PredictionService.forecast(records, settings)?.nextStart;
      }

      if (nextStart == null) {
        if (_mayHaveScheduledReminders) {
          await notifications.cancelAll();
          _mayHaveScheduledReminders = false;
        }
        _setReminderState(nextReminderAt: null, error: null);
        return;
      }

      _mayHaveScheduledReminders = true;
      final scheduled = await notifications.schedulePeriodReminders(
        nextStart,
        _reminderDays,
        _reminderTime,
      );
      _setReminderState(
        nextReminderAt: scheduled.isEmpty ? null : scheduled.first.time,
        error: null,
      );
    } on Object catch (error) {
      debugPrint('安排提醒失敗: $error');
      _setReminderState(nextReminderAt: null, error: _reminderErrorText(error));
    }
  }

  /// A short reason for settings; platform errors otherwise include a full
  /// Java stack trace.
  static String _reminderErrorText(Object error) {
    if (error is PlatformException) return error.message ?? error.code;
    if (error is StateError) return error.message;
    return '$error';
  }

  void _setReminderState({DateTime? nextReminderAt, String? error}) {
    if (_nextReminderAt == nextReminderAt && _reminderError == error) return;
    _nextReminderAt = nextReminderAt;
    _reminderError = error;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  int _validCycleLength(int? value) {
    if (value == null ||
        value < AppConstants.minCycleLength ||
        value > AppConstants.maxCycleLength) {
      return AppConstants.defaultCycleLength;
    }
    return value;
  }

  int _validPeriodLength(int? value) {
    if (value == null ||
        value < AppConstants.minPeriodLength ||
        value > AppConstants.maxPeriodLength) {
      return AppConstants.defaultPeriodLength;
    }
    return value;
  }

  Set<int> _parseReminderDays(List<String>? values) {
    final parsed = values
            ?.map(int.tryParse)
            .whereType<int>()
            .where(AppConstants.reminderDayOptions.contains)
            .toSet() ??
        <int>{1};
    return parsed;
  }

  TimeOfDay _parseTime(
    String? value, {
    TimeOfDay fallback = const TimeOfDay(hour: 9, minute: 0),
    bool throwOnInvalid = false,
  }) {
    final parts = value?.split(':');
    final hour = parts?.length == 2 ? int.tryParse(parts![0]) : null;
    final minute = parts?.length == 2 ? int.tryParse(parts![1]) : null;
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      if (throwOnInvalid) throw const FormatException('提醒時間格式不正確');
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}
