import 'package:flutter/foundation.dart';

enum FlowIntensity {
  light,
  medium,
  heavy,
}

class PeriodRecord {
  final int? id;
  final DateTime startDate;
  final DateTime? endDate;
  final int painLevel;
  final Map<String, bool> symptoms;
  final FlowIntensity flowIntensity;
  final String? notes;

  PeriodRecord({
    this.id,
    required this.startDate,
    this.endDate,
    this.painLevel = 1,
    Map<String, bool>? symptoms,
    this.flowIntensity = FlowIntensity.medium,
    this.notes,
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
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'painLevel': painLevel,
      'symptoms': symptoms,
      'flowIntensity': flowIntensity.toString(),
      'notes': notes,
    };
  }

  factory PeriodRecord.fromJson(Map<String, dynamic> json) {
    return PeriodRecord(
      id: json['id'] != null ? json['id'] as int : null,  // 明確轉換為 int
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      painLevel: (json['painLevel'] as num?)?.toInt() ?? 1,  // 處理可能的 double 值
      symptoms: Map<String, bool>.from(json['symptoms'] ?? {}),
      flowIntensity: _parseFlowIntensity(json['flowIntensity'] as String?),
      notes: json['notes'] as String?,
    );
  }

  static FlowIntensity _parseFlowIntensity(String? value) {
    switch (value) {
      case 'FlowIntensity.light':
        return FlowIntensity.light;
      case 'FlowIntensity.heavy':
        return FlowIntensity.heavy;
      case 'FlowIntensity.medium':
      default:
        return FlowIntensity.medium;
    }
  }

  PeriodRecord copyWith({
    int? id,
    DateTime? startDate,
    DateTime? endDate,
    int? painLevel,
    Map<String, bool>? symptoms,
    FlowIntensity? flowIntensity,
    String? notes,
  }) {
    return PeriodRecord(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      painLevel: painLevel ?? this.painLevel,
      symptoms: symptoms ?? Map<String, bool>.from(this.symptoms),
      flowIntensity: flowIntensity ?? this.flowIntensity,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'PeriodRecord(id: $id, startDate: $startDate, endDate: $endDate, '
        'painLevel: $painLevel, symptoms: $symptoms, flowIntensity: $flowIntensity, '
        'notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is PeriodRecord &&
      other.id == id &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.painLevel == painLevel &&
      mapEquals(other.symptoms, symptoms) &&
      other.flowIntensity == flowIntensity &&
      other.notes == notes;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      painLevel.hashCode ^
      symptoms.hashCode ^
      flowIntensity.hashCode ^
      notes.hashCode;
  }
}