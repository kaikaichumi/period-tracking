import 'package:flutter/material.dart';
import '../models/period_record.dart';

class UserSettingsProvider extends ChangeNotifier {
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  int _cycleLength = 28;
  int _periodLength = 5;
  bool _notificationsEnabled = true;

  TimeOfDay get reminderTime => _reminderTime;
  int get cycleLength => _cycleLength;
  int get periodLength => _periodLength;
  bool get notificationsEnabled => _notificationsEnabled;

  void updateReminderTime(TimeOfDay newTime) {
    _reminderTime = newTime;
    notifyListeners();
  }

  void updateCycleLength(int length) {
    _cycleLength = length;
    notifyListeners();
  }

  void updatePeriodLength(int length) {
    _periodLength = length;
    notifyListeners();
  }

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }
}