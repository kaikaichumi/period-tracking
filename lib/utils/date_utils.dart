// lib/utils/date_utils.dart
import 'package:intl/intl.dart';

class DateUtils {
  static final DateFormat _dateFormatter = DateFormat('yyyy/MM/dd');

  static String formatDate(DateTime date) {
    return _dateFormatter.format(date);
  }

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Moves by calendar days, so a 23- or 25-hour daylight-saving day never
  /// shifts the result to the wrong date.
  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// Calendar days from [from] to [to], ignoring the time of day.
  static int daysBetween(DateTime from, DateTime to) {
    return DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
  }
}
