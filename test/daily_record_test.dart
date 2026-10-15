import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/models/daily_record.dart';

void main() {
  test('存檔時 enum 用名稱、症狀用代號，讀回來內容不變', () {
    final record = DailyRecord(
      id: 3,
      date: DateTime(2026, 5, 1),
      hasPeriod: true,
      bleedingLevel: BleedingLevel.heavy,
      painLevel: 6,
      symptoms: <String, bool>{'headache': true, 'bloating': false},
      hasIntimacy: true,
      intimacyFrequency: 2,
      contraceptionMethod: ContraceptionMethod.condom,
      notes: '備註',
    );

    final json = record.toJson();
    expect(json['bleedingLevel'], 'heavy');
    expect(json['contraceptionMethod'], 'condom');
    expect(json['symptoms'], <String, bool>{
      'headache': true,
      'bloating': false,
    });

    final restored = DailyRecord.fromJson(json);
    expect(restored.bleedingLevel, BleedingLevel.heavy);
    expect(restored.contraceptionMethod, ContraceptionMethod.condom);
    expect(restored.symptoms, record.symptoms);
    expect(restored.painLevel, 6);
    expect(restored.intimacyFrequency, 2);
    expect(restored.notes, '備註');
  });

  test('舊格式（數字 enum、中文症狀）可以讀取並轉成新格式', () {
    final record = DailyRecord.fromJson(<String, dynamic>{
      'id': 0,
      'date': '2025-02-01T00:00:00.000',
      'hasPeriod': true,
      'bleedingLevel': 3,
      'painLevel': 4,
      'symptoms': <String, dynamic>{'頭痛': true, '腰痛': false},
      'hasIntimacy': true,
      'intimacyFrequency': 1,
      'contraceptionMethod': 1,
      'notes': null,
      'intimacyNotes': null,
      'isPeriodEndDay': false,
    });

    expect(record.bleedingLevel, BleedingLevel.medium);
    expect(record.contraceptionMethod, ContraceptionMethod.condom);
    expect(record.symptoms, <String, bool>{
      'headache': true,
      'back_pain': false,
    });
  });

  test('不認得的症狀保留原樣，不認得的 enum 值視為格式錯誤', () {
    final record = DailyRecord.fromJson(<String, dynamic>{
      'date': '2025-02-01T00:00:00.000',
      'symptoms': <String, dynamic>{'經痛': true},
    });
    expect(record.symptoms, <String, bool>{'經痛': true});

    expect(
      () => DailyRecord.fromJson(<String, dynamic>{
        'date': '2025-02-01T00:00:00.000',
        'bleedingLevel': 'extreme',
      }),
      throwsFormatException,
    );
    expect(
      () => DailyRecord.fromJson(<String, dynamic>{
        'date': '2025-02-01T00:00:00.000',
        'contraceptionMethod': 99,
      }),
      throwsFormatException,
    );
  });
}
