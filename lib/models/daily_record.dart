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
  final bool hasPeriod;  // 是否為經期
  final BleedingLevel? bleedingLevel;  // 出血量
  final int? painLevel;  // 經痛程度 1-10
  final Map<String, bool> symptoms;  // 症狀
  
  // 親密關係相關
  final bool hasIntimacy;
  final int? intimacyFrequency;
  final ContraceptionMethod? contraceptionMethod;
  
  // 備註
  final String? notes;
  final String? intimacyNotes;

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
    );
  }

  @override
  String toString() {
    return 'DailyRecord(id: $id, date: $date, hasPeriod: $hasPeriod, '
        'bleedingLevel: $bleedingLevel, painLevel: $painLevel, '
        'symptoms: $symptoms, hasIntimacy: $hasIntimacy, '
        'intimacyFrequency: $intimacyFrequency, '
        'contraceptionMethod: $contraceptionMethod, '
        'notes: $notes, intimacyNotes: $intimacyNotes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is DailyRecord &&
      other.id == id &&
      other.date == date &&
      other.hasPeriod == hasPeriod &&
      other.bleedingLevel == bleedingLevel &&
      other.painLevel == painLevel &&
      mapEquals(other.symptoms, symptoms) &&
      other.hasIntimacy == hasIntimacy &&
      other.intimacyFrequency == intimacyFrequency &&
      other.contraceptionMethod == contraceptionMethod &&
      other.notes == notes &&
      other.intimacyNotes == intimacyNotes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      date.hashCode ^
      hasPeriod.hashCode ^
      bleedingLevel.hashCode ^
      painLevel.hashCode ^
      symptoms.hashCode ^
      hasIntimacy.hashCode ^
      intimacyFrequency.hashCode ^
      contraceptionMethod.hashCode ^
      notes.hashCode ^
      intimacyNotes.hashCode;
  }
}