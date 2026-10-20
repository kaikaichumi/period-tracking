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

  /// iOS 版 Google 登入的 OAuth 用戶端 ID（結尾是 .apps.googleusercontent.com）。
  /// 要建立在和 Android 相同的 Google Cloud 專案，兩邊才看得到同一份備份；
  /// 反轉後的 ID 也必須加進 ios/Runner/Info.plist 的 CFBundleURLTypes，否則登入時
  /// App 會閃退。留空時 iOS 版不提供 Google Drive 備份。
  static const String googleIosClientId = '';

  /// 可選的提醒日（預估經期開始前幾天）。
  static const Set<int> reminderDayOptions = <int>{0, 1, 3, 7};

  /// 可記錄的症狀（依顯示順序）：儲存用的代號 → 畫面上的名稱。
  /// 代號會寫進記錄與備份，不能改；名稱可以隨時調整。
  static const Map<String, String> symptomLabels = <String, String>{
    'mood_changes': '情緒變化',
    'breast_tenderness': '乳房脹痛',
    'back_pain': '腰痛',
    'headache': '頭痛',
    'fatigue': '疲勞',
    'acne': '痘痘',
    'nausea': '噁心',
    'appetite_changes': '食慾改變',
    'insomnia': '失眠',
    'bloating': '腹脹',
  };

  /// 症狀代號的顯示名稱；不認得的代號（例如舊版本留下的）直接顯示原文。
  static String symptomLabel(String id) => symptomLabels[id] ?? id;
}
