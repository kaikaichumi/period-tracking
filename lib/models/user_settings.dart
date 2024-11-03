// lib/models/user_settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class UserSettings {
  int cycleLength;
  int periodLength;
  bool notificationsEnabled;
  TimeOfDay reminderTime;

  UserSettings({
    this.cycleLength = AppConstants.defaultCycleLength,
    this.periodLength = AppConstants.defaultPeriodLength,
    this.notificationsEnabled = true,
    TimeOfDay? reminderTime,
  }) : reminderTime = reminderTime ?? TimeOfDay(hour: 20, minute: 0);

  // 從 SharedPreferences 創建設定
  static Future<UserSettings> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    return UserSettings(
      cycleLength: prefs.getInt(AppConstants.prefsCycleLength) ?? 
          AppConstants.defaultCycleLength,
      periodLength: prefs.getInt('period_length') ?? 
          AppConstants.defaultPeriodLength,
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
      reminderTime: _timeOfDayFromString(
        prefs.getString('reminder_time') ?? '20:00',
      ),
    );
  }

  // 將設定保存到 SharedPreferences
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(AppConstants.prefsCycleLength, cycleLength);
    await prefs.setInt('period_length', periodLength);
    await prefs.setBool('notifications_enabled', notificationsEnabled);
    await prefs.setString(
      'reminder_time',
      '${reminderTime.hour}:${reminderTime.minute}',
    );
  }

  // 將 TimeOfDay 轉換為字符串
  static TimeOfDay _timeOfDayFromString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  // 複製設定並修改特定值
  UserSettings copyWith({
    int? cycleLength,
    int? periodLength,
    bool? notificationsEnabled,
    TimeOfDay? reminderTime,
  }) {
    return UserSettings(
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

// 使用 ChangeNotifier 管理設定狀態
class UserSettingsProvider extends ChangeNotifier {
  UserSettings? _settings;
  bool _isLoading = true;

  UserSettingsProvider() {
    _loadSettings();
  }

  bool get isLoading => _isLoading;
  
  UserSettings get settings {
    if (_settings == null) {
      _settings = UserSettings();
    }
    return _settings!;
  }

  int get cycleLength => settings.cycleLength;
  int get periodLength => settings.periodLength;
  bool get notificationsEnabled => settings.notificationsEnabled;
  TimeOfDay get reminderTime => settings.reminderTime;

  // 載入設定
  Future<void> _loadSettings() async {
    try {
      _settings = await UserSettings.fromPrefs();
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _settings = UserSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 更新週期長度
  Future<void> updateCycleLength(int newLength) async {
    if (newLength >= AppConstants.minCycleLength && 
        newLength <= AppConstants.maxCycleLength) {
      _settings = settings.copyWith(cycleLength: newLength);
      await _saveSettings();
    }
  }

  // 更新經期長度
  Future<void> updatePeriodLength(int newLength) async {
    if (newLength > 0 && newLength <= 10) {
      _settings = settings.copyWith(periodLength: newLength);
      await _saveSettings();
    }
  }

  // 更新通知開關
  Future<void> updateNotificationsEnabled(bool enabled) async {
    _settings = settings.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }

  // 更新提醒時間
  Future<void> updateReminderTime(TimeOfDay newTime) async {
    _settings = settings.copyWith(reminderTime: newTime);
    await _saveSettings();
  }

  // 保存設定
  Future<void> _saveSettings() async {
    try {
      await settings.saveToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving settings: $e');
      // 這裡可以添加錯誤處理邏輯
    }
  }

  // 重置設定到預設值
  Future<void> resetToDefaults() async {
    _settings = UserSettings();
    await _saveSettings();
  }

  // 導出設定為JSON
  Map<String, dynamic> toJson() {
    return {
      'cycleLength': settings.cycleLength,
      'periodLength': settings.periodLength,
      'notificationsEnabled': settings.notificationsEnabled,
      'reminderTime': '${settings.reminderTime.hour}:${settings.reminderTime.minute}',
    };
  }

  // 從JSON導入設定
  Future<void> fromJson(Map<String, dynamic> json) async {
    _settings = UserSettings(
      cycleLength: json['cycleLength'] ?? AppConstants.defaultCycleLength,
      periodLength: json['periodLength'] ?? AppConstants.defaultPeriodLength,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      reminderTime: _parseTimeString(json['reminderTime'] ?? '20:00'),
    );
    await _saveSettings();
  }

  // 解析時間字符串
  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}