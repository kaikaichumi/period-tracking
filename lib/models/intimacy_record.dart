import 'package:flutter/foundation.dart';

// 避免與 daily_record.dart 中的枚舉衝突，移除此處的枚舉定義
enum ContraceptionMethod {
  none,
  condom,
  pill,
  iud,
  calendar,
  withdrawal,
  other,
}

class IntimacyRecord {
  final int? id;  // 確保這裡是 int? 類型
  final DateTime date;
  final int frequency;
  final ContraceptionMethod contraceptionMethod;
  final String? notes;

  IntimacyRecord({
    this.id,
    required this.date,
    this.frequency = 1,
    this.contraceptionMethod = ContraceptionMethod.none,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'frequency': frequency,
      'contraceptionMethod': contraceptionMethod.toString(),
      'notes': notes,
    };
  }

  factory IntimacyRecord.fromJson(Map<String, dynamic> json) {
    return IntimacyRecord(
      id: json['id'] != null ? json['id'] as int : null,  // 確保正確解析 int 類型
      date: DateTime.parse(json['date'] as String),
      frequency: (json['frequency'] as num?)?.toInt() ?? 1,
      contraceptionMethod: _parseContraceptionMethod(json['contraceptionMethod'] as String?),
      notes: json['notes'] as String?,
    );
  }

  static ContraceptionMethod _parseContraceptionMethod(String? value) {
    switch (value) {
      case 'ContraceptionMethod.condom':
        return ContraceptionMethod.condom;
      case 'ContraceptionMethod.pill':
        return ContraceptionMethod.pill;
      case 'ContraceptionMethod.iud':
        return ContraceptionMethod.iud;
      case 'ContraceptionMethod.calendar':
        return ContraceptionMethod.calendar;
      case 'ContraceptionMethod.withdrawal':
        return ContraceptionMethod.withdrawal;
      case 'ContraceptionMethod.other':
        return ContraceptionMethod.other;
      case 'ContraceptionMethod.none':
      default:
        return ContraceptionMethod.none;
    }
  }

  IntimacyRecord copyWith({
    int? id,
    DateTime? date,
    int? frequency,
    ContraceptionMethod? contraceptionMethod,
    String? notes,
  }) {
    return IntimacyRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      frequency: frequency ?? this.frequency,
      contraceptionMethod: contraceptionMethod ?? this.contraceptionMethod,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'IntimacyRecord(id: $id, date: $date, frequency: $frequency, '
        'contraceptionMethod: $contraceptionMethod, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is IntimacyRecord &&
      other.id == id &&
      other.date == date &&
      other.frequency == frequency &&
      other.contraceptionMethod == contraceptionMethod &&
      other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      date.hashCode ^
      frequency.hashCode ^
      contraceptionMethod.hashCode ^
      notes.hashCode;
  }
}