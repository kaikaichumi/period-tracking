// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../utils/date_utils.dart' as date_utils;
import '../models/daily_record.dart';
// 為兩個衝突的導入添加別名
import '../models/user_settings.dart' as settings_model;
import '../providers/user_settings_provider.dart' as settings_provider;

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<DateTime> _predictions = [];
  List<DailyRecord> _records = [];
  int _predictionConfidence = 50;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final records = await DatabaseService.instance.getAllDailyRecords();
      final settingsProvider = context.read<settings_provider.UserSettingsProvider>();
      
      // 創建 UserSettings 物件
      final settings = settings_model.UserSettings(
        cycleLength: settingsProvider.cycleLength,
        periodLength: settingsProvider.periodLength,
      );
      
      // 使用創建的 settings 物件
      final stats = PredictionService.getStatistics(records, settings);
      final predictions = PredictionService.predictNextPeriods(records, settings);
      final confidence = PredictionService.getPredictionConfidence(records);
      
      setState(() {
        _records = records;
        _stats = stats;
        _predictions = predictions;
        _predictionConfidence = confidence;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsCard(
          title: '週期統計',
          children: [
            _buildStatRow(
              label: '平均週期長度',
              value: '${_stats['averageCycleLength']} 天',
            ),
            _buildStatRow(
              label: '平均經期長度',
              value: '${_stats['averagePeriodLength']} 天',
            ),
            _buildStatRow(
              label: '週期規律性',
              value: '${(_stats['cycleRegularity'] * 100).round()}%',
            ),
            if (_stats['isUsingSettings'])
              _buildWarningText('因記錄次數不足，部分數據使用設定值'),
          ],
        ),
        const SizedBox(height: 16),
        _buildPredictionsCard(),
        const SizedBox(height: 16),
        _buildSymptomStatsCard(),
        if (_records.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRecordStatsCard(),
        ],
      ],
    );
  }

  Widget _buildStatsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '預測下次經期',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Tooltip(
                  message: '預測準確度',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(_predictionConfidence),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_predictionConfidence}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._predictions.asMap().entries.map((entry) {
              final index = entry.key;
              final date = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.pink[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.pink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      date_utils.DateUtils.formatDate(date),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }),
            if (_stats['isUsingSettings'])
              _buildWarningText('預測是根據設定的預設週期計算，可能不準確'),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomStatsCard() {
    final symptoms = (_stats['commonSymptoms'] as List<String>?) ?? [];
    if (symptoms.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '常見症狀',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text('尚無症狀記錄'),
            ],
          ),
        ),
      );
    }

    return _buildStatsCard(
      title: '常見症狀',
      children: symptoms.map((symptom) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.pink),
              const SizedBox(width: 8),
              Expanded(child: Text(symptom)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordStatsCard() {
    final periodDays = _records.where((r) => r.hasPeriod).length;
    final intimacyDays = _records.where((r) => r.hasIntimacy).length;
    final symptomDays = _records.where((r) => 
      r.symptoms.values.any((hasSymptom) => hasSymptom)).length;
      
    final averagePain = _stats['averagePainLevel'] ?? '0.0';

    return _buildStatsCard(
      title: '記錄統計',
      children: [
        _buildStatRow(
          label: '總記錄天數',
          value: '${_records.length} 天',
        ),
        _buildStatRow(
          label: '經期天數',
          value: '$periodDays 天',
        ),
        _buildStatRow(
          label: '平均經痛程度',
          value: '$averagePain / 10',
        ),
        _buildStatRow(
          label: '親密關係記錄',
          value: '$intimacyDays 天',
        ),
        _buildStatRow(
          label: '症狀記錄',
          value: '$symptomDays 天',
        ),
        if (_stats['totalPeriods'] != null)
          _buildStatRow(
            label: '記錄週期數',
            value: '${_stats['totalPeriods']} 次',
          ),
        if (_stats['lastPeriodStart'] != null)
          _buildStatRow(
            label: '最近一次經期',
            value: date_utils.DateUtils.formatDate(_stats['lastPeriodStart']),
          ),
      ],
    );
  }

  Widget _buildStatRow({
    required String label, 
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.orange[700],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }
}