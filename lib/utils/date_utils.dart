// lib/utils/date_utils.dart (新增)
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

  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }
}