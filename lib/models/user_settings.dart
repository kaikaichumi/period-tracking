import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class UserSettings {
  UserSettings({
    this.cycleLength = AppConstants.defaultCycleLength,
    this.periodLength = AppConstants.defaultPeriodLength,
    this.notificationsEnabled = false,
    TimeOfDay? reminderTime,
    Set<int>? reminderDays,
  })  : reminderTime = reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
        reminderDays = reminderDays ?? <int>{1};

  int cycleLength;
  int periodLength;
  bool notificationsEnabled;
  TimeOfDay reminderTime;
  Set<int> reminderDays;

  static Future<UserSettings> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cycleLength = prefs.getInt(AppConstants.prefsCycleLength);
    final periodLength = prefs.getInt('period_length');
    return UserSettings(
      cycleLength: cycleLength != null &&
              cycleLength >= AppConstants.minCycleLength &&
              cycleLength <= AppConstants.maxCycleLength
          ? cycleLength
          : AppConstants.defaultCycleLength,
      periodLength:
          periodLength != null && periodLength >= 1 && periodLength <= 10
              ? periodLength
              : AppConstants.defaultPeriodLength,
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? false,
      reminderTime: _timeOfDayFromString(
        prefs.getString('reminder_time') ?? '09:00',
      ),
      reminderDays: prefs
              .getStringList('reminder_days')
              ?.map(int.tryParse)
              .whereType<int>()
              .where(const <int>{0, 1, 3, 7}.contains)
              .toSet() ??
          <int>{1},
    );
  }

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
      reminderDays.map((day) => day.toString()).toList(),
    );
  }

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
      reminderDays: reminderDays ?? Set<int>.from(this.reminderDays),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'notificationsEnabled': notificationsEnabled,
        'reminderTime': '${reminderTime.hour}:${reminderTime.minute}',
        'reminderDays': reminderDays.toList(),
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      cycleLength:
          json['cycleLength'] as int? ?? AppConstants.defaultCycleLength,
      periodLength:
          json['periodLength'] as int? ?? AppConstants.defaultPeriodLength,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      reminderTime:
          _timeOfDayFromString(json['reminderTime']?.toString() ?? '09:00'),
      reminderDays:
          (json['reminderDays'] as List<dynamic>?)?.whereType<int>().toSet() ??
              <int>{1},
    );
  }

  static TimeOfDay _timeOfDayFromString(String value) {
    final parts = value.split(':');
    final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  bool operator ==(Object other) {
    return other is UserSettings &&
        other.cycleLength == cycleLength &&
        other.periodLength == periodLength &&
        other.notificationsEnabled == notificationsEnabled &&
        other.reminderTime == reminderTime &&
        setEquals(other.reminderDays, reminderDays);
  }

  @override
  int get hashCode => Object.hash(
        cycleLength,
        periodLength,
        notificationsEnabled,
        reminderTime,
        Object.hashAllUnordered(reminderDays),
      );
}
