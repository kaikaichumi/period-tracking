// lib/utils/constants.dart (更新)
class AppConstants {
  // 共享偏好設定鍵
  static const String prefsCycleLength = 'cycle_length';
  static const String prefsNotificationsEnabled = 'notifications_enabled';
  static const String prefsReminderTime = 'reminder_time';
  
  // 預設值
  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;
  static const int minCycleLength = 21;
  static const int maxCycleLength = 35;
}