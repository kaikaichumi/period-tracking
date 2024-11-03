// lib/utils/constants.dart
class AppConstants {
  // 資料庫名稱
  static const String dbName = 'period_tracker.db';
  
  // 共享偏好設定鍵
  static const String prefsCycleLength = 'cycle_length';
  static const String prefsNotificationsEnabled = 'notifications_enabled';
  static const String prefsReminderTime = 'reminder_time';
  
  
  // 預設值
  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;
  static const int minCycleLength = 21;
  static const int maxCycleLength = 35;
  
  // 症狀列表
  static const Map<String, String> symptoms = {
    'mood': '情緒變化',
    'breast': '乳房脹痛',
    'backache': '腰痛',
    'headache': '頭痛',
    'fatigue': '疲勞',
    'acne': '痘痘',
    'nausea': '噁心',
    'appetite': '食慾改變',
    'insomnia': '失眠',
    'bloating': '腹脹',
  };
  // 新增常量定義
  static const Map<String, String> contraceptionMethods = {
    'none': '無避孕措施',
    'condom': '保險套',
    'pill': '口服避孕藥',
    'iud': '子宮內避孕器',
    'calendar': '安全期計算',
    'withdrawal': '體外射精',
    'other': '其他',
  };

  static const Map<String, String> flowLevels = {
    'none': '無',
    'spotting': '點滴',
    'light': '輕',
    'medium': '中',
    'heavy': '重',
  };
}

