// lib/services/prediction_service.dart
import '../models/period_record.dart';

class PredictionService {
  static DateTime predictNextPeriod(List<PeriodRecord> records, int cycleLength) {
    if (records.isEmpty) {
      return DateTime.now().add(Duration(days: cycleLength));
    }

    // 按日期排序
    records.sort((a, b) => b.startDate.compareTo(a.startDate));
    
    // 取最近的記錄
    final lastPeriod = records.first;
    
    // 如果有多個記錄，計算平均週期長度
    if (records.length > 1) {
      int totalDays = 0;
      int count = 0;
      
      for (int i = 0; i < records.length - 1; i++) {
        final difference = records[i].startDate.difference(records[i + 1].startDate).inDays;
        if (difference > 0 && difference < 45) { // 排除異常值
          totalDays += difference;
          count++;
        }
      }
      
      if (count > 0) {
        cycleLength = (totalDays / count).round();
      }
    }
    
    return lastPeriod.startDate.add(Duration(days: cycleLength));
  }

  static List<DateTime> predictNext3Periods(List<PeriodRecord> records, int cycleLength) {
    List<DateTime> predictions = [];
    DateTime nextPeriod = predictNextPeriod(records, cycleLength);
    
    predictions.add(nextPeriod);
    predictions.add(nextPeriod.add(Duration(days: cycleLength)));
    predictions.add(nextPeriod.add(Duration(days: cycleLength * 2)));
    
    return predictions;
  }
}