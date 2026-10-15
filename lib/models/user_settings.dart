import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
