// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';
import '../models/daily_record.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await DatabaseService.instance.getStatistics();
      setState(() {
        _stats = stats;
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
          stats: [
            StatsItem(
              label: '平均週期長度',
              value: '${_stats['averageCycleLength']?.toStringAsFixed(1) ?? '0'} 天',
            ),
            StatsItem(
              label: '平均經期長度',
              value: '${_stats['averagePeriodLength']?.toStringAsFixed(1) ?? '0'} 天',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatsCard(
          title: '常見症狀',
          stats: (_stats['commonSymptoms'] as List<String>? ?? [])
              .map((symptom) => StatsItem(label: symptom, value: ''))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatsCard({
    required String title,
    required List<StatsItem> stats,
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
            ...stats.map((stat) => _buildStatItem(stat)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(StatsItem stat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(stat.label),
          if (stat.value.isNotEmpty) Text(stat.value),
        ],
      ),
    );
  }
}

class StatsItem {
  final String label;
  final String value;

  StatsItem({required this.label, required this.value});
}