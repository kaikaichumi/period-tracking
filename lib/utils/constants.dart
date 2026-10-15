// lib/utils/constants.dart
class AppConstants {
  // 共享偏好設定鍵
  static const String prefsCycleLength = 'cycle_length';
  static const String prefsPeriodLength = 'period_length';
  static const String prefsNotificationsEnabled = 'notifications_enabled';
  static const String prefsReminderTime = 'reminder_time';
  static const String prefsReminderDays = 'reminder_days';

  // 預設值與允許範圍
  static const int defaultCycleLength = 28;
  static const int defaultPeriodLength = 5;
  static const int minCycleLength = 21;
  static const int maxCycleLength = 35;
  static const int minPeriodLength = 1;
  static const int maxPeriodLength = 10;

  /// 可選的提醒日（預估經期開始前幾天）。
  static const Set<int> reminderDayOptions = <int>{0, 1, 3, 7};

  /// 可記錄的症狀。這些文字同時是已儲存資料的鍵，改名會讓舊記錄對不上。
  static const List<String> symptoms = <String>[
    '情緒變化',
    '乳房脹痛',
    '腰痛',
    '頭痛',
    '疲勞',
    '痘痘',
    '噁心',
    '食慾改變',
    '失眠',
    '腹脹',
  ];
}
