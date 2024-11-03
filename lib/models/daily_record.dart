// lib/models/daily_record.dart
class DailyRecord {
  final String id;
  final DateTime date;
  final bool hasPeriod;
  final BleedingLevel? bleedingLevel;  // 出血量
  final PainLevel? painLevel;          // 經痛程度
  final List<Symptom> symptoms;        // 症狀
  final IntimateRecord? intimateRecord; // 性行為紀錄
  
  DailyRecord({
    required this.id,
    required this.date,
    required this.hasPeriod,
    this.bleedingLevel,
    this.painLevel,
    this.symptoms = const [],
    this.intimateRecord,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'hasPeriod': hasPeriod,
    'bleedingLevel': bleedingLevel?.index,
    'painLevel': painLevel?.index,
    'symptoms': symptoms.map((s) => s.index).toList(),
    'intimateRecord': intimateRecord?.toJson(),
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    id: json['id'],
    date: DateTime.parse(json['date']),
    hasPeriod: json['hasPeriod'],
    bleedingLevel: json['bleedingLevel'] != null 
      ? BleedingLevel.values[json['bleedingLevel']]
      : null,
    painLevel: json['painLevel'] != null 
      ? PainLevel.values[json['painLevel']]
      : null,
    symptoms: (json['symptoms'] as List)
      .map((i) => Symptom.values[i]).toList(),
    intimateRecord: json['intimateRecord'] != null
      ? IntimateRecord.fromJson(json['intimateRecord'])
      : null,
  );
}

// lib/models/intimate_record.dart
class IntimateRecord {
  final int frequency;
  final ContraceptionMethod? contraceptionMethod;

  IntimateRecord({
    required this.frequency,
    this.contraceptionMethod,
  });

  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'contraceptionMethod': contraceptionMethod?.index,
  };

  factory IntimateRecord.fromJson(Map<String, dynamic> json) => IntimateRecord(
    frequency: json['frequency'],
    contraceptionMethod: json['contraceptionMethod'] != null
      ? ContraceptionMethod.values[json['contraceptionMethod']]
      : null,
  );
}

// lib/utils/constants.dart
enum BleedingLevel {
  light,
  medium,
  heavy,
}

enum PainLevel {
  none,
  mild,
  moderate,
  severe,
}

enum Symptom {
  headache,
  breastTenderness,
  bloating,
  mood,
  fatigue,
  // 其他症狀...
}

enum ContraceptionMethod {
  condom,
  pill,
  iud,
  none,
  other,
}