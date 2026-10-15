import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../providers/user_settings_provider.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../utils/date_utils.dart' as date_utils;

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = <String, dynamic>{};
  PeriodForecast? _forecast;
  List<DailyRecord> _records = <DailyRecord>[];
  int? _predictionRangeDays;
  int _loadToken = 0;
  UserSettingsProvider? _settingsProvider;

  @override
  void initState() {
    super.initState();
    DatabaseService.instance.revision.addListener(_handleDataChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<UserSettingsProvider>();
    if (!identical(_settingsProvider, provider)) {
      _settingsProvider?.removeListener(_handleDataChanged);
      _settingsProvider = provider;
      provider.addListener(_handleDataChanged);
      _loadStats();
    }
  }

  @override
  void dispose() {
    DatabaseService.instance.revision.removeListener(_handleDataChanged);
    _settingsProvider?.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() => _loadStats();

  Future<void> _loadStats() async {
    final token = ++_loadToken;
    final records = await DatabaseService.instance.getAllDailyRecords();
    if (!mounted || token != _loadToken) return;
    final settings = context.read<UserSettingsProvider>().settings;
    setState(() {
      _records = records;
      _stats = PredictionService.getStatistics(records, settings);
      _forecast = PredictionService.forecast(records, settings);
      _predictionRangeDays = PredictionService.predictionRangeDays(records);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分析')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: _records.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: <Widget>[
                        _buildCycleStatsCard(),
                        const SizedBox(height: 12),
                        _buildPredictionsCard(),
                        const SizedBox(height: 12),
                        _buildSymptomStatsCard(),
                        const SizedBox(height: 12),
                        _buildRecordStatsCard(),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: <Widget>[
        const SizedBox(height: 96),
        Icon(
          Icons.insights_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          '還沒有可分析的資料',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          '先到「日曆」記錄一次經期。沒有真實資料前，LunaCare 不會顯示虛構的預測日期或可信度。',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCycleStatsCard() {
    final regularity = _stats['cycleRegularity'] as double?;
    final usingSettings = _stats['isUsingSettings'] as bool? ?? true;
    return _statsCard(
      title: '週期概況',
      children: <Widget>[
        _statRow(
          label: '週期長度',
          value: '${_stats['cycleLength']} 天${usingSettings ? '（設定值）' : ''}',
        ),
        _statRow(
          label: '經期長度',
          value: '${_stats['periodLength']} 天',
        ),
        _statRow(
          label: '週期規律性',
          value: regularity == null ? '資料不足' : '${(regularity * 100).round()}%',
        ),
        _infoText(
          usingSettings
              ? '至少需要 2 次經期開始日才能算出你的實際週期，3 次以上才能比較規律性。'
              : '取最近 ${PredictionService.recentCycleCount} 次的中位數，偶爾漏記一次也不會把數字拉偏。',
        ),
        if (!usingSettings && regularity == null)
          _infoText('至少需要 3 次經期開始日，才能比較週期間隔與規律性。'),
      ],
    );
  }

  Widget _buildPredictionsCard() {
    final forecast = _forecast;
    if (forecast == null) {
      return _statsCard(
        title: '經期預估',
        children: <Widget>[
          const Text('尚未記錄經期開始日，因此目前無法預估。'),
        ],
      );
    }

    if (forecast.isLate) {
      return _statsCard(
        title: '經期預估',
        children: <Widget>[
          _statRow(label: '比預估晚了', value: '${forecast.daysLate} 天'),
          _statRow(
            label: '原本預估',
            value: date_utils.DateUtils.formatDate(forecast.expectedStart),
          ),
          _infoText('記錄這次經期的開始日後，就會重新預估接下來的日期。'),
        ],
      );
    }

    return _statsCard(
      title: '接下來的經期預估',
      trailing: Chip(
        avatar: const Icon(Icons.query_stats, size: 18),
        label: Text(
          _predictionRangeDays == null
              ? '誤差：資料不足'
              : '誤差 ±$_predictionRangeDays 天',
        ),
      ),
      children: <Widget>[
        ...forecast.upcomingStarts.asMap().entries.map((entry) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              child: Text('${entry.key + 1}'),
            ),
            title: Text(date_utils.DateUtils.formatDate(entry.value)),
          );
        }),
        _infoText(
          forecast.isStale
              ? '已超過一個週期沒有新的經期記錄，以上只是依舊資料推算，僅供參考。'
              : forecast.cyclesUsed == 0
                  ? '目前以設定的週期長度估算，僅供安排與觀察，不代表醫療判斷。'
                  : '預估會隨你新增或修正經期記錄而更新。',
        ),
      ],
    );
  }

  Widget _buildSymptomStatsCard() {
    final symptoms = (_stats['commonSymptoms'] as List<dynamic>? ?? <dynamic>[])
        .whereType<String>()
        .toList();
    return _statsCard(
      title: '常見症狀',
      children: symptoms.isEmpty
          ? <Widget>[const Text('尚無症狀記錄。')]
          : symptoms
              .map(
                (symptom) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(symptom),
                ),
              )
              .toList(),
    );
  }

  Widget _buildRecordStatsCard() {
    final periodDays = _records.where((record) => record.hasPeriod).length;
    final intimacyDays = _records.where((record) => record.hasIntimacy).length;
    final symptomDays = _records
        .where((record) => record.symptoms.values.any((value) => value))
        .length;
    final averagePain = _stats['averagePainLevel'] as String?;

    return _statsCard(
      title: '記錄摘要',
      children: <Widget>[
        _statRow(label: '總記錄天數', value: '${_records.length} 天'),
        _statRow(label: '經期天數', value: '$periodDays 天'),
        _statRow(
          label: '平均疼痛程度',
          value: averagePain == null ? '尚無資料' : '$averagePain / 10',
        ),
        _statRow(label: '性行為記錄', value: '$intimacyDays 天'),
        _statRow(label: '症狀記錄', value: '$symptomDays 天'),
        _statRow(label: '經期次數', value: '${_stats['totalPeriods']} 次'),
        if (_stats['lastPeriodStart'] is DateTime)
          _statRow(
            label: '最近一次經期開始',
            value: date_utils.DateUtils.formatDate(
              _stats['lastPeriodStart'] as DateTime,
            ),
          ),
      ],
    );
  }

  Widget _statsCard({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _statRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 17,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
