// lib/providers/user_settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class UserSettingsProvider extends ChangeNotifier {
  // 內部狀態
  int _cycleLength = AppConstants.defaultCycleLength;
  int _periodLength = AppConstants.defaultPeriodLength;
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _reminderDays = {1}; // 預設一天前提醒
  bool _isLoading = true;

  // Getters
  bool get isLoading => _isLoading;
  int get cycleLength => _cycleLength;
  int get periodLength => _periodLength;
  bool get notificationsEnabled => _notificationsEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  Set<int> get reminderDays => _reminderDays;

  UserSettingsProvider() {
    _loadSettings();
  }

  // 載入設定
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _cycleLength = prefs.getInt(AppConstants.prefsCycleLength) ?? 
          AppConstants.defaultCycleLength;
      _periodLength = prefs.getInt('period_length') ?? 
          AppConstants.defaultPeriodLength;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      
      // 載入提醒時間
      final timeString = prefs.getString('reminder_time') ?? '09:00';
      final timeParts = timeString.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );

      // 載入提醒天數
      final reminderDaysStr = prefs.getStringList('reminder_days') ?? ['1'];
      _reminderDays = reminderDaysStr.map(int.parse).toSet();

      _isLoading = false;
      notifyListeners();

      // 如果通知已啟用，重新安排提醒
      if (_notificationsEnabled) {
        _scheduleNotifications();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // 儲存設定
  Future<void> _saveSettings() async {
    try {
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
        _reminderDays.map((d) => d.toString()).toList(),
      );
      
      notifyListeners();
      
      // 如果通知已啟用，重新安排提醒
      if (_notificationsEnabled) {
        await _scheduleNotifications();
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // 更新週期長度
  Future<void> updateCycleLength(int newLength) async {
    if (newLength >= AppConstants.minCycleLength && 
        newLength <= AppConstants.maxCycleLength) {
      _cycleLength = newLength;
      await _saveSettings();
    }
  }

  // 更新經期長度
  Future<void> updatePeriodLength(int newLength) async {
    if (newLength > 0 && newLength <= 10) {
      _periodLength = newLength;
      await _saveSettings();
    }
  }

  // 更新通知開關
  Future<void> updateNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    
    if (!enabled) {
      // 如果關閉通知，取消所有提醒
      await NotificationService.instance.cancelAll();
    }
    
    await _saveSettings();
  }

  // 更新提醒時間
  Future<void> updateReminderTime(TimeOfDay newTime) async {
    _reminderTime = newTime;
    await _saveSettings();
  }

  // 更新提醒天數
  Future<void> updateReminderDays(Set<int> days) async {
    _reminderDays = days;
    await _saveSettings();
  }

  // 安排通知
  Future<void> _scheduleNotifications() async {
    try {
      // 先取消現有的通知
      await NotificationService.instance.cancelAll();
      
      // 如果通知已關閉，直接返回
      if (!_notificationsEnabled) return;

      // 獲取預測的下次經期日期
      final nextPeriod = await _getNextPeriodDate();
      
      // 安排新的通知
      await NotificationService.instance.schedulePeriodReminders(
        nextPeriod,
        _reminderDays,
        _reminderTime,
      );
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }

  // 預測下次經期日期
  Future<DateTime> _getNextPeriodDate() async {
    final records = await DatabaseService.instance.getAllDailyRecords();
    if (records.isEmpty) {
      return DateTime.now().add(Duration(days: _cycleLength));
    }

    // 找到最後一次經期開始的日期
    records.sort((a, b) => b.date.compareTo(a.date));
    final lastPeriodStart = records.firstWhere((r) => r.hasPeriod).date;
    
    // 計算下次經期日期
    return lastPeriodStart.add(Duration(days: _cycleLength));
  }

  // 導出設定為 JSON
  Map<String, dynamic> toJson() {
    return {
      'cycleLength': _cycleLength,
      'periodLength': _periodLength,
      'notificationsEnabled': _notificationsEnabled,
      'reminderTime': '${_reminderTime.hour}:${_reminderTime.minute}',
      'reminderDays': _reminderDays.toList(),
    };
  }

  // 從 JSON 導入設定
  Future<void> fromJson(Map<String, dynamic> json) async {
    _cycleLength = json['cycleLength'] ?? AppConstants.defaultCycleLength;
    _periodLength = json['periodLength'] ?? AppConstants.defaultPeriodLength;
    _notificationsEnabled = json['notificationsEnabled'] ?? true;
    
    final timeString = json['reminderTime'] ?? '09:00';
    final timeParts = timeString.split(':');
    _reminderTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    _reminderDays = (json['reminderDays'] as List<dynamic>?)
        ?.map((e) => e as int)
        ?.toSet() ?? {1};

    await _saveSettings();
  }

  // 重置為預設值
  Future<void> resetToDefaults() async {
    _cycleLength = AppConstants.defaultCycleLength;
    _periodLength = AppConstants.defaultPeriodLength;
    _notificationsEnabled = true;
    _reminderTime = const TimeOfDay(hour: 9, minute: 0);
    _reminderDays = {1};
    
    await _saveSettings();
  }
}