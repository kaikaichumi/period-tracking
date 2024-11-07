// lib/models/daily_record.dart
import 'package:flutter/foundation.dart';

enum BleedingLevel {
  none,
  spotting,
  light,
  medium,
  heavy,
}

enum ContraceptionMethod {
  none,
  condom,
  pill,
  iud,
  calendar,
  withdrawal,
  other,
}

class DailyRecord {
  final int? id;
  final DateTime date;
  final bool hasPeriod;
  final BleedingLevel? bleedingLevel;
  final int? painLevel;
  final Map<String, bool> symptoms;
  final bool hasIntimacy;
  final int? intimacyFrequency;
  final ContraceptionMethod? contraceptionMethod;
  final String? notes;
  final String? intimacyNotes;
  final bool isPeriodEndDay;  // 新增屬性

  DailyRecord({
    this.id,
    required this.date,
    this.hasPeriod = false,
    this.bleedingLevel,
    this.painLevel,
    Map<String, bool>? symptoms,
    this.hasIntimacy = false,
    this.intimacyFrequency,
    this.contraceptionMethod,
    this.notes,
    this.intimacyNotes,
    this.isPeriodEndDay = false,  // 預設為 false
  }) : symptoms = symptoms ?? {
    '情緒變化': false,
    '乳房脹痛': false,
    '腰痛': false,
    '頭痛': false,
    '疲勞': false,
    '痘痘': false,
    '噁心': false,
    '食慾改變': false,
    '失眠': false,
    '腹脹': false,
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'hasPeriod': hasPeriod,
      'bleedingLevel': bleedingLevel?.index,
      'painLevel': painLevel,
      'symptoms': symptoms,
      'hasIntimacy': hasIntimacy,
      'intimacyFrequency': intimacyFrequency,
      'contraceptionMethod': contraceptionMethod?.index,
      'notes': notes,
      'intimacyNotes': intimacyNotes,
      'isPeriodEndDay': isPeriodEndDay,  // 新增字段
    };
  }

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      id: json['id'] as int?,
      date: DateTime.parse(json['date'] as String),
      hasPeriod: json['hasPeriod'] as bool? ?? false,
      bleedingLevel: json['bleedingLevel'] != null
          ? BleedingLevel.values[json['bleedingLevel'] as int]
          : null,
      painLevel: json['painLevel'] as int?,
      symptoms: Map<String, bool>.from(json['symptoms'] ?? {}),
      hasIntimacy: json['hasIntimacy'] as bool? ?? false,
      intimacyFrequency: json['intimacyFrequency'] as int?,
      contraceptionMethod: json['contraceptionMethod'] != null
          ? ContraceptionMethod.values[json['contraceptionMethod'] as int]
          : null,
      notes: json['notes'] as String?,
      intimacyNotes: json['intimacyNotes'] as String?,
      isPeriodEndDay: json['isPeriodEndDay'] as bool? ?? false,  // 新增解析
    );
  }

  DailyRecord copyWith({
    int? id,
    DateTime? date,
    bool? hasPeriod,
    BleedingLevel? bleedingLevel,
    int? painLevel,
    Map<String, bool>? symptoms,
    bool? hasIntimacy,
    int? intimacyFrequency,
    ContraceptionMethod? contraceptionMethod,
    String? notes,
    String? intimacyNotes,
    bool? isPeriodEndDay,  // 新增參數
  }) {
    return DailyRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      hasPeriod: hasPeriod ?? this.hasPeriod,
      bleedingLevel: bleedingLevel ?? this.bleedingLevel,
      painLevel: painLevel ?? this.painLevel,
      symptoms: symptoms ?? Map<String, bool>.from(this.symptoms),
      hasIntimacy: hasIntimacy ?? this.hasIntimacy,
      intimacyFrequency: intimacyFrequency ?? this.intimacyFrequency,
      contraceptionMethod: contraceptionMethod ?? this.contraceptionMethod,
      notes: notes ?? this.notes,
      intimacyNotes: intimacyNotes ?? this.intimacyNotes,
      isPeriodEndDay: isPeriodEndDay ?? this.isPeriodEndDay,  // 新增複製
    );
  }
}