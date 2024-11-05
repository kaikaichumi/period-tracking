// lib/providers/user_settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class UserSettings {
  final int cycleLength;
  final int periodLength;
  final bool notificationsEnabled;
  final TimeOfDay reminderTime;
  final Set<int> reminderDays;

  UserSettings({
    this.cycleLength = AppConstants.defaultCycleLength,
    this.periodLength = AppConstants.defaultPeriodLength,
    this.notificationsEnabled = true,
    TimeOfDay? reminderTime,
    Set<int>? reminderDays,
  }) : reminderTime = reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
       reminderDays = reminderDays ?? {1}; // 預設一天前提醒

  UserSettings copyWith({
    int? cycleLength,
    int? periodLength,
    bool? notificationsEnabled,
    TimeOfDay? reminderTime,
    Set<int>? reminderDays,
  }) {
    return UserSettings(
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? this.reminderDays,
    );
  }
}

class UserSettingsProvider extends ChangeNotifier {
  UserSettings _settings = UserSettings();
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  UserSettings get settings => _settings;
  int get cycleLength => _settings.cycleLength;
  int get periodLength => _settings.periodLength;
  bool get notificationsEnabled => _settings.notificationsEnabled;
  TimeOfDay get reminderTime => _settings.reminderTime;
  Set<int> get reminderDays => _settings.reminderDays;

  UserSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _settings = UserSettings(
        cycleLength: prefs.getInt(AppConstants.prefsCycleLength) ?? 
            AppConstants.defaultCycleLength,
        periodLength: prefs.getInt('period_length') ?? 
            AppConstants.defaultPeriodLength,
        notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
        reminderTime: _timeOfDayFromString(
          prefs.getString('reminder_time') ?? '09:00',
        ),
        reminderDays: (prefs.getStringList('reminder_days') ?? ['1'])
            .map(int.parse)
            .toSet(),
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(AppConstants.prefsCycleLength, _settings.cycleLength);
      await prefs.setInt('period_length', _settings.periodLength);
      await prefs.setBool('notifications_enabled', _settings.notificationsEnabled);
      await prefs.setString(
        'reminder_time',
        '${_settings.reminderTime.hour}:${_settings.reminderTime.minute}',
      );
      await prefs.setStringList(
        'reminder_days',
        _settings.reminderDays.map((d) => d.toString()).toList(),
      );
      
      notifyListeners();
      
      // 如果通知已啟用，重新安排提醒
      if (_settings.notificationsEnabled) {
        final nextPeriod = await getPredictedNextPeriod();
        await NotificationService.instance.schedulePeriodReminders(
          nextPeriod,
          _settings.reminderDays,
          _settings.reminderTime,
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> updateCycleLength(int newLength) async {
    if (newLength >= AppConstants.minCycleLength && 
        newLength <= AppConstants.maxCycleLength) {
      _settings = _settings.copyWith(cycleLength: newLength);
      await _saveSettings();
    }
  }

  Future<void> updatePeriodLength(int newLength) async {
    if (newLength > 0 && newLength <= 10) {
      _settings = _settings.copyWith(periodLength: newLength);
      await _saveSettings();
    }
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    
    if (!enabled) {
      // 如果關閉通知，取消所有提醒
      await NotificationService.instance.cancelAll();
    }
    
    await _saveSettings();
  }

  Future<void> updateReminderTime(TimeOfDay newTime) async {
    _settings = _settings.copyWith(reminderTime: newTime);
    await _saveSettings();
  }

  Future<void> updateReminderDays(Set<int> days) async {
    _settings = _settings.copyWith(reminderDays: days);
    await _saveSettings();
  }

  // 重置為預設設定
  Future<void> resetToDefaults() async {
    _settings = UserSettings();
    await _saveSettings();
  }

  // 獲取預測的下次經期日期
  Future<DateTime> getPredictedNextPeriod() async {
    try {
      final records = await DatabaseService.instance.getAllDailyRecords();
      if (records.isEmpty) {
        return DateTime.now().add(Duration(days: _settings.cycleLength));
      }

      // 找到最後一次經期開始的日期
      records.sort((a, b) => b.date.compareTo(a.date));
      final lastPeriodStart = records.firstWhere((r) => r.hasPeriod).date;
      
      // 計算下次經期日期
      return lastPeriodStart.add(Duration(days: _settings.cycleLength));
    } catch (e) {
      debugPrint('Error predicting next period: $e');
      // 如果發生錯誤，返回預設值
      return DateTime.now().add(Duration(days: _settings.cycleLength));
    }
  }

  static TimeOfDay _timeOfDayFromString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}