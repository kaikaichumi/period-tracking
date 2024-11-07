// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../models/user_settings.dart' as settings_model;
import '../providers/user_settings_provider.dart' as settings_provider;
import '../models/daily_record.dart';
import '../widgets/add_record_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 添加所需的類別屬性
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, DailyRecord> _events = {};
  bool _isLoading = false;
  DateTime? _currentPeriodStart;
  List<(DateTime date, bool isPrediction)> _periodDates = [];
  int _predictionConfidence = 50;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final records = await DatabaseService.instance.getAllDailyRecords();
      
      if (!mounted) return;
      final settingsProvider = context.read<settings_provider.UserSettingsProvider>();
      final settings = settings_model.UserSettings(
        cycleLength: settingsProvider.cycleLength,
        periodLength: settingsProvider.periodLength,
      );
      
      _calculatePeriodDates(records, settings);
      _predictionConfidence = PredictionService.getPredictionConfidence(records);
      
      final Map<DateTime, DailyRecord> newEvents = {};
      for (final record in records) {
        final date = DateTime(record.date.year, record.date.month, record.date.day);
        newEvents[date] = record;

        if (record.hasPeriod && 
            (_currentPeriodStart == null ||
             record.date.isAfter(_currentPeriodStart!))) {
          _currentPeriodStart = record.date;
        }

        // 檢查是否為經期結束日
        if (!record.hasPeriod) {
          final previousDay = date.subtract(const Duration(days: 1));
          final previousRecord = records.firstWhereOrNull(
            (r) => isSameDay(r.date, previousDay) && r.hasPeriod
          );
          if (previousRecord != null) {
            newEvents[date] = record.copyWith(isPeriodEndDay: true);
          }
        }
      }

      setState(() {
        _events = newEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculatePeriodDates(List<DailyRecord> records, settings_model.UserSettings settings) {
    _periodDates = [];
    
    final actualPeriods = PredictionService.findPeriodDetails(records);
    for (var period in actualPeriods) {
      for (int i = 0; i < period.$2; i++) {
        _periodDates.add((
          period.$1.add(Duration(days: i)),
          false
        ));
      }
    }

    final predictions = PredictionService.predictNextPeriods(records, settings);
    final averagePeriodLength = actualPeriods.isEmpty 
        ? settings.periodLength
        : (actualPeriods.map((p) => p.$2).reduce((a, b) => a + b) / actualPeriods.length).round();
    
    for (var predictedStart in predictions) {
      for (int i = 0; i < averagePeriodLength; i++) {
        _periodDates.add((
          predictedStart.add(Duration(days: i)),
          true
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月經週期追蹤'),
        centerTitle: true,
        actions: [
          if (_predictionConfidence < 100)
            Tooltip(
              message: '預測準確度',
              child: Container(
                margin: const EdgeInsets.only(right: 16),
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
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final normalizedDate = DateTime(date.year, date.month, date.day);

                if (_events.containsKey(normalizedDate)) {
                  return _buildMarker(_events[normalizedDate]!);
                }

                final periodInfo = _periodDates.firstWhereOrNull(
                  (pd) => isSameDay(pd.$1, normalizedDate)
                );
                
                if (periodInfo != null) {
                  return _buildPeriodMarker(periodInfo.$2);
                }

                return null;
              },
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.pink,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.pinkAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: _buildEventList(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecordSheet(_selectedDay ?? _focusedDay),
        child: const Icon(Icons.add),
        backgroundColor: Colors.pink,
      ),
    );
  }

  Widget _buildMarker(DailyRecord record) {
    if (record.hasPeriod || record.isPeriodEndDay) {
      return Positioned(
        bottom: 1,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.pink,
          ),
          width: 8,
          height: 8,
        ),
      );
    }
    
    if (record.hasIntimacy) {
      return Positioned(
        bottom: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple[300],
          ),
          width: 8,
          height: 8,
        ),
      );
    } 
    
    if (record.symptoms.values.any((v) => v)) {
      return Positioned(
        bottom: 1,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
          ),
          width: 8,
          height: 8,
        ),
      );
    }

    return Container();
  }

  Widget _buildPeriodMarker(bool isPrediction) {
    return Positioned(
      bottom: 1,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrediction ? Colors.pink[50] : Colors.pink,
          border: isPrediction ? Border.all(
            color: Colors.pink[300]!,
            width: 1,
          ) : null,
        ),
        width: 8,
        height: 8,
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  void _showAddRecordSheet(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AddRecordSheet(
            selectedDate: date,
            existingRecord: _events[date],
            onSave: (record) async {
              await DatabaseService.instance.saveDailyRecord(record);
              await _loadEvents();  // 重新載入資料以更新顯示
            }, onDelete: () {  },
          ),
        );
      },
    );
  }


  Widget _buildEventList() {
    final selectedDate = _selectedDay ?? _focusedDay;
    final eventDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    
    final record = _events[eventDate];
    final periodInfo = _periodDates.firstWhereOrNull(
      (pd) => isSameDay(pd.$1, eventDate)
    );

    if (record == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_currentPeriodStart != null) Text(
            '目前週期開始於：${DateFormat('yyyy/MM/dd').format(_currentPeriodStart!)}',
            style: const TextStyle(fontSize: 16),
          ),
          if (periodInfo != null && periodInfo.$2) ...[
            const SizedBox(height: 8),
            Text(
              '預測經期日期',
              style: TextStyle(
                fontSize: 16,
                color: Colors.pink[300],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '準確度: $_predictionConfidence%',
              style: TextStyle(
                fontSize: 14,
                color: _getConfidenceColor(_predictionConfidence),
              ),
            ),
          ],
          if (periodInfo == null && _currentPeriodStart == null)
            const Text('點擊右下角按鈕來記錄'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (record.hasPeriod || record.isPeriodEndDay) _buildPeriodCard(record),
        if (record.symptoms.values.any((v) => v)) _buildSymptomsCard(record),
        if (record.hasIntimacy) _buildIntimacyCard(record),
        if (record.notes?.isNotEmpty ?? false) _buildNotesCard(record),
      ],
    );
  }

  // ... 其餘的卡片建構方法保持不變 ...

  Widget _buildPeriodCard(DailyRecord record) {
    return Card(
      child: ListTile(
        title: Text(
          '月經記錄',
          style: TextStyle(
            color: Colors.pink[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.bleedingLevel != null)
              Text('出血量：${_bleedingLevelToString(record.bleedingLevel!)}'),
            if (record.painLevel != null)
              Text('經痛程度：${record.painLevel}/10'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showAddRecordSheet(_selectedDay!),
        ),
      ),
    );
  }

  Widget _buildSymptomsCard(DailyRecord record) {
    final activeSymptoms = record.symptoms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    return Card(
      child: ListTile(
        title: const Text(
          '症狀',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(activeSymptoms.join('、')),
      ),
    );
  }

  Widget _buildIntimacyCard(DailyRecord record) {
    return Card(
      child: ListTile(
        title: const Text(
          '親密關係記錄',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('次數：${record.intimacyFrequency ?? 1}'),
            if (record.contraceptionMethod != null)
              Text('避孕方式：${_contraceptionMethodToString(record.contraceptionMethod!)}'),
            if (record.intimacyNotes?.isNotEmpty ?? false)
              Text('備註：${record.intimacyNotes}'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(DailyRecord record) {
    return Card(
      child: ListTile(
        title: const Text(
          '備註',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(record.notes!),
      ),
    );
  }

  String _bleedingLevelToString(BleedingLevel level) {
    switch (level) {
      case BleedingLevel.spotting:
        return '點滴';
      case BleedingLevel.light:
        return '輕';
      case BleedingLevel.medium:
        return '中';
      case BleedingLevel.heavy:
        return '重';
      default:
        return '無';
    }
  }

  String _contraceptionMethodToString(ContraceptionMethod method) {
    switch (method) {
      case ContraceptionMethod.none:
        return '無避孕措施';
      case ContraceptionMethod.condom:
        return '保險套';
      case ContraceptionMethod.pill:
        return '口服避孕藥';
      case ContraceptionMethod.iud:
        return '子宮內避孕器';
      case ContraceptionMethod.calendar:
        return '安全期計算';
      case ContraceptionMethod.withdrawal:
        return '體外射精';
      case ContraceptionMethod.other:
        return '其他';
    }
  }
}