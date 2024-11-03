// lib/screens/statistics_screen.dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/period_record.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PeriodRecord> _records = [];
  bool _isLoading = true;
  
  // 統計數據
  double _averageCycleLength = 0;
  double _averagePeriodLength = 0;
  Map<String, int> _symptomFrequency = {};
  double _averagePainLevel = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 載入所有記錄
      final records = await DatabaseService.instance.getAllPeriods();
      records.sort((a, b) => b.startDate.compareTo(a.startDate));

      // 計算週期長度
      List<int> cycleLengths = [];
      for (int i = 0; i < records.length - 1; i++) {
        final difference = records[i + 1].startDate.difference(records[i].startDate).inDays;
        if (difference > 0 && difference < 45) { // 排除異常值
          cycleLengths.add(difference);
        }
      }

      // 計算經期長度
      List<int> periodLengths = [];
      for (var record in records) {
        if (record.endDate != null) {
          final length = record.endDate!.difference(record.startDate).inDays + 1;
          if (length > 0 && length < 15) { // 排除異常值
            periodLengths.add(length);
          }
        }
      }

      // 統計症狀頻率
      Map<String, int> symptomCounts = {};
      for (var record in records) {
        record.symptoms.forEach((symptom, hasSymptom) {
          if (hasSymptom) {
            symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
          }
        });
      }

      // 計算平均經痛程度
      double totalPainLevel = records.fold(0, (sum, record) => sum + record.painLevel);

      setState(() {
        _records = records;
        _averageCycleLength = cycleLengths.isEmpty 
            ? 0 
            : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
        _averagePeriodLength = periodLengths.isEmpty 
            ? 0 
            : periodLengths.reduce((a, b) => a + b) / periodLengths.length;
        _symptomFrequency = symptomCounts;
        _averagePainLevel = records.isEmpty ? 0 : totalPainLevel / records.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入數據時發生錯誤：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計分析'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '基本統計'),
            Tab(text: '症狀分析'),
            Tab(text: '週期趨勢'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBasicStatistics(),
                _buildSymptomStatistics(),
                _buildTrendAnalysis(),
              ],
            ),
    );
  }

  Widget _buildBasicStatistics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            title: '平均週期長度',
            value: '${_averageCycleLength.toStringAsFixed(1)} 天',
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: '平均經期長度',
            value: '${_averagePeriodLength.toStringAsFixed(1)} 天',
            icon: Icons.hourglass_empty,
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: '平均經痛程度',
            value: '${_averagePainLevel.toStringAsFixed(1)}/10',
            icon: Icons.healing,
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomStatistics() {
    final sortedSymptoms = _symptomFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedSymptoms.length,
      itemBuilder: (context, index) {
        final entry = sortedSymptoms[index];
        final percentage = _records.isEmpty 
            ? 0.0 
            : (entry.value / _records.length * 100);
        
        return Column(
          children: [
            ListTile(
              title: Text(entry.key),
              trailing: Text('${percentage.toStringAsFixed(1)}%'),
            ),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[300]!),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildTrendAnalysis() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        final dateFormat = DateFormat('yyyy/MM/dd');
        
        return Card(
          child: ListTile(
            title: Text(dateFormat.format(record.startDate)),
            subtitle: Text(
              '持續時間: ${record.endDate != null ? record.endDate!.difference(record.startDate).inDays + 1 : "未結束"} 天\n'
              '經痛程度: ${record.painLevel}/10',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.pink[300]),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.pink[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}