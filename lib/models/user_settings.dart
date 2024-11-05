// lib/models/user_settings.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class UserSettings {
  int cycleLength;
  int periodLength;
  bool notificationsEnabled;
  TimeOfDay reminderTime;
  Set<int> reminderDays; // 提醒天數（7=一週前, 3=三天前, 1=一天前, 0=當天）

  UserSettings({
    this.cycleLength = AppConstants.defaultCycleLength,
    this.periodLength = AppConstants.defaultPeriodLength,
    this.notificationsEnabled = true,
    TimeOfDay? reminderTime,
    Set<int>? reminderDays,
  }) : reminderTime = reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
       reminderDays = reminderDays ?? {1}; // 預設一天前提醒

  // 從 SharedPreferences 創建設定
  static Future<UserSettings> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 讀取提醒天數
    final reminderDaysStr = prefs.getStringList('reminder_days') ?? ['1'];
    final reminderDays = reminderDaysStr.map(int.parse).toSet();
    
    return UserSettings(
      cycleLength: prefs.getInt(AppConstants.prefsCycleLength) ?? 
          AppConstants.defaultCycleLength,
      periodLength: prefs.getInt('period_length') ?? 
          AppConstants.defaultPeriodLength,
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
      reminderTime: _timeOfDayFromString(
        prefs.getString('reminder_time') ?? '09:00',
      ),
      reminderDays: reminderDays,
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
    await prefs.setStringList(
      'reminder_days',
      reminderDays.map((d) => d.toString()).toList(),
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
    Set<int>? reminderDays,
  }) {
    return UserSettings(
      cycleLength: cycleLength ?? this.cycleLength,
      periodLength: periodLength ?? this.periodLength,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDays: reminderDays ?? Set.from(this.reminderDays),
    );
  }

  // 獲取提醒天數的描述文字
  String getReminderDaysDescription() {
    if (reminderDays.isEmpty) return '未設定';
    
    final List<String> descriptions = [];
    if (reminderDays.contains(7)) descriptions.add('一週前');
    if (reminderDays.contains(3)) descriptions.add('三天前');
    if (reminderDays.contains(1)) descriptions.add('一天前');
    if (reminderDays.contains(0)) descriptions.add('當天');
    
    return descriptions.join('、');
  }

  // 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'cycleLength': cycleLength,
      'periodLength': periodLength,
      'notificationsEnabled': notificationsEnabled,
      'reminderTime': '${reminderTime.hour}:${reminderTime.minute}',
      'reminderDays': reminderDays.toList(),
    };
  }

  // 從 JSON 創建設定
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      cycleLength: json['cycleLength'] ?? AppConstants.defaultCycleLength,
      periodLength: json['periodLength'] ?? AppConstants.defaultPeriodLength,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      reminderTime: _timeOfDayFromString(json['reminderTime'] ?? '09:00'),
      reminderDays: (json['reminderDays'] as List<dynamic>?)?.map((e) => e as int).toSet() ?? {1},
    );
  }

  @override
  String toString() {
    return 'UserSettings(cycleLength: $cycleLength, periodLength: $periodLength, '
           'notificationsEnabled: $notificationsEnabled, '
           'reminderTime: ${reminderTime.hour}:${reminderTime.minute}, '
           'reminderDays: $reminderDays)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is UserSettings &&
      other.cycleLength == cycleLength &&
      other.periodLength == periodLength &&
      other.notificationsEnabled == notificationsEnabled &&
      other.reminderTime.hour == reminderTime.hour &&
      other.reminderTime.minute == reminderTime.minute &&
      setEquals(other.reminderDays, reminderDays);
  }

  @override
  int get hashCode {
    return cycleLength.hashCode ^
      periodLength.hashCode ^
      notificationsEnabled.hashCode ^
      reminderTime.hashCode ^
      reminderDays.hashCode;
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
  Set<int> get reminderDays => settings.reminderDays;

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

  // 更新提醒開關
  Future<void> updateNotificationsEnabled(bool enabled) async {
    _settings = settings.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }

  // 更新提醒時間
  Future<void> updateReminderTime(TimeOfDay newTime) async {
    _settings = settings.copyWith(reminderTime: newTime);
    await _saveSettings();
  }

  // 更新提醒天數
  Future<void> updateReminderDays(Set<int> days) async {
    _settings = settings.copyWith(reminderDays: days);
    await _saveSettings();
  }

  // 保存設定
  Future<void> _saveSettings() async {
    try {
      await settings.saveToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // 重置為預設值
  Future<void> resetToDefaults() async {
    _settings = UserSettings();
    await _saveSettings();
  }
}