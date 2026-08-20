import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_settings.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class UserSettingsProvider extends ChangeNotifier {
  int _cycleLength = AppConstants.defaultCycleLength;
  int _periodLength = AppConstants.defaultPeriodLength;
  bool _notificationsEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _reminderDays = <int>{1};
  bool _isLoading = true;

  UserSettingsProvider() {
    _loadSettings();
  }

  bool get isLoading => _isLoading;
  int get cycleLength => _cycleLength;
  int get periodLength => _periodLength;
  bool get notificationsEnabled => _notificationsEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  Set<int> get reminderDays => Set<int>.unmodifiable(_reminderDays);

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
      _periodLength = _validPeriodLength(prefs.getInt('period_length'));
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _reminderTime = _parseTime(
        prefs.getString('reminder_time'),
        fallback: const TimeOfDay(hour: 9, minute: 0),
      );
      _reminderDays = _parseReminderDays(
        prefs.getStringList('reminder_days'),
      );
    } on Object catch (error) {
      debugPrint('讀取設定失敗，已使用預設值: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (_notificationsEnabled) {
      try {
        await _scheduleNotifications();
      } on Object catch (error) {
        debugPrint('安排提醒失敗: $error');
      }
    }
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
    if (newLength < 1 || newLength > 10) {
      throw ArgumentError.value(newLength, 'newLength', '經期長度超出範圍');
    }
    _periodLength = newLength;
    await _saveSettings();
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    if (!enabled) await NotificationService.instance.cancelAll();
    await _saveSettings();
  }

  Future<void> updateReminderTime(TimeOfDay newTime) async {
    _reminderTime = newTime;
    await _saveSettings();
  }

  Future<void> updateReminderDays(Set<int> days) async {
    if (!days.every(_allowedReminderDays.contains)) {
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
        periodLength < 1 ||
        periodLength > 10 ||
        notificationsEnabled is! bool ||
        reminderTime is! String ||
        reminderDays is! List) {
      throw const FormatException('備份中的設定格式不正確');
    }

    final parsedDays = reminderDays.map((value) {
      if (value is! int) throw const FormatException('提醒日期格式不正確');
      return value;
    }).toSet();
    if (!parsedDays.every(_allowedReminderDays.contains)) {
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
    await NotificationService.instance.cancelAll();
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefsCycleLength, _cycleLength);
    await prefs.setInt('period_length', _periodLength);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString(
      'reminder_time',
      '${_reminderTime.hour}:${_reminderTime.minute}',
    );
    await prefs.setStringList(
      'reminder_days',
      _reminderDays.map((day) => day.toString()).toList(),
    );
    notifyListeners();
    if (_notificationsEnabled) {
      try {
        await _scheduleNotifications();
      } on Object catch (error) {
        debugPrint('安排提醒失敗: $error');
      }
    }
  }

  Future<void> _scheduleNotifications() async {
    final lastStart = await DatabaseService.instance.findLastPeriodStartDate();
    if (lastStart == null) {
      await NotificationService.instance.cancelAll();
      return;
    }

    var nextPeriod = lastStart.add(Duration(days: _cycleLength));
    final today = DateTime.now();
    while (!nextPeriod.isAfter(today)) {
      nextPeriod = nextPeriod.add(Duration(days: _cycleLength));
    }
    await NotificationService.instance.schedulePeriodReminders(
      nextPeriod,
      _reminderDays,
      _reminderTime,
    );
  }

  static const Set<int> _allowedReminderDays = <int>{0, 1, 3, 7};

  int _validCycleLength(int? value) {
    if (value == null ||
        value < AppConstants.minCycleLength ||
        value > AppConstants.maxCycleLength) {
      return AppConstants.defaultCycleLength;
    }
    return value;
  }

  int _validPeriodLength(int? value) {
    if (value == null || value < 1 || value > 10) {
      return AppConstants.defaultPeriodLength;
    }
    return value;
  }

  Set<int> _parseReminderDays(List<String>? values) {
    final parsed = values
            ?.map(int.tryParse)
            .whereType<int>()
            .where(_allowedReminderDays.contains)
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
