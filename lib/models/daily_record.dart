// lib/models/daily_record.dart
import '../utils/constants.dart';

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
  final bool isPeriodEndDay; // 新增屬性

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
    this.isPeriodEndDay = false, // 預設為 false
  }) : symptoms = symptoms ??
            <String, bool>{
              for (final id in AppConstants.symptomLabels.keys) id: false,
            };

  /// Enums are stored by name and symptoms by ID, so reordering an enum or
  /// renaming a symptom label can't change what saved records mean.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'hasPeriod': hasPeriod,
      'bleedingLevel': bleedingLevel?.name,
      'painLevel': painLevel,
      'symptoms': symptoms,
      'hasIntimacy': hasIntimacy,
      'intimacyFrequency': intimacyFrequency,
      'contraceptionMethod': contraceptionMethod?.name,
      'notes': notes,
      'intimacyNotes': intimacyNotes,
      'isPeriodEndDay': isPeriodEndDay, // 新增字段
    };
  }

  /// Reads the current format as well as the earlier one, which stored enums
  /// by index and symptoms by their Chinese label.
  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      id: json['id'] as int?,
      date: DateTime.parse(json['date'] as String),
      hasPeriod: json['hasPeriod'] as bool? ?? false,
      bleedingLevel: _enumFromJson(
        BleedingLevel.values,
        json['bleedingLevel'],
        '出血量資料格式不正確',
      ),
      painLevel: json['painLevel'] as int?,
      symptoms: _symptomsFromJson(json['symptoms']),
      hasIntimacy: json['hasIntimacy'] as bool? ?? false,
      intimacyFrequency: json['intimacyFrequency'] as int?,
      contraceptionMethod: _enumFromJson(
        ContraceptionMethod.values,
        json['contraceptionMethod'],
        '避孕方式資料格式不正確',
      ),
      notes: json['notes'] as String?,
      intimacyNotes: json['intimacyNotes'] as String?,
      isPeriodEndDay: json['isPeriodEndDay'] as bool? ?? false, // 新增解析
    );
  }

  static T? _enumFromJson<T extends Enum>(
    List<T> values,
    Object? raw,
    String error,
  ) {
    if (raw == null) return null;
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
    } else if (raw is int && raw >= 0 && raw < values.length) {
      return values[raw];
    }
    throw FormatException(error);
  }

  static final Map<String, String> _symptomIdsByLabel = <String, String>{
    for (final entry in AppConstants.symptomLabels.entries)
      entry.value: entry.key,
  };

  /// Converts old label keys to IDs; keys it doesn't know are kept as is.
  static Map<String, bool> _symptomsFromJson(Object? raw) {
    if (raw == null) return <String, bool>{};
    if (raw is! Map) throw const FormatException('症狀資料格式不正確');
    final symptoms = <String, bool>{};
    raw.forEach((key, value) {
      if (key is! String || value is! bool) {
        throw const FormatException('症狀資料格式不正確');
      }
      symptoms[_symptomIdsByLabel[key] ?? key] = value;
    });
    return symptoms;
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
    bool? isPeriodEndDay, // 新增參數
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
      isPeriodEndDay: isPeriodEndDay ?? this.isPeriodEndDay, // 新增複製
    );
  }
}
