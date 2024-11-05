// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/daily_record.dart';
import '../widgets/add_record_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, DailyRecord> _events = {};
  bool _isLoading = false;
  DateTime? _currentPeriodStart;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final records = await DatabaseService.instance.getAllDailyRecords();
      final periodDays = await DatabaseService.instance.getAllPeriodDays();
      
      // 將記錄轉換為 Map 格式
      final Map<DateTime, DailyRecord> newEvents = {};
      
      // 首先添加所有實際的記錄
      for (final record in records) {
        final date = DateTime(record.date.year, record.date.month, record.date.day);
        newEvents[date] = record;

        // 更新當前經期開始日期
        if (record.hasPeriod && 
            (record.date.isAfter(_currentPeriodStart ?? DateTime(1900)) ||
             _currentPeriodStart == null)) {
          _currentPeriodStart = record.date;
        }
      }

      // 為經期中的每一天添加記錄
      for (final date in periodDays) {
        final normalizedDate = DateTime(date.year, date.month, date.day);
        if (!newEvents.containsKey(normalizedDate)) {
          // 如果這一天沒有具體記錄，添加一個基本的經期記錄
          newEvents[normalizedDate] = DailyRecord(
            date: normalizedDate,
            hasPeriod: true,
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月經週期追蹤'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: (day) {
              final eventDay = DateTime(day.year, day.month, day.day);
              return _events.containsKey(eventDay) ? [_events[eventDay]!] : [];
            },
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
                if (events.isEmpty) return null;
                
                final record = events.first as DailyRecord;
                return _buildMarker(record);
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
  if (record.hasPeriod) {
    // 經期開始和期間都用粉紅色
    return Positioned(
      bottom: 1,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.pink,  // 統一使用粉紅色
        ),
        width: 8,
        height: 8,
      ),
    );
  } else {
    // 檢查是否為經期結束日
    bool isEndOfPeriod = false;
    
    // 檢查前一天是否為經期
    final previousDay = DateTime(
      record.date.year,
      record.date.month,
      record.date.day - 1,
    );
    final previousDate = _events[previousDay];
    if (previousDate != null && previousDate.hasPeriod) {
      isEndOfPeriod = true;
    }

    if (isEndOfPeriod) {
      // 經期結束日也用粉紅色
      return Positioned(
        bottom: 1,
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.pink,  // 結束日也用粉紅色
          ),
          width: 8,
          height: 8,
        ),
      );
    }
    
    // 其他記錄的顯示邏輯
    if (record.hasIntimacy) {
      return Positioned(
        bottom: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.pink[300]!,
          ),
          width: 8,
          height: 8,
        ),
      );
    } else if (record.symptoms.values.any((v) => v)) {
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
  }

  return Container(); // 如果沒有任何記錄，返回空容器
}

  Widget _buildEventList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedDate = _selectedDay ?? _focusedDay;
    final eventDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final record = _events[eventDate];

    if (record == null) {
      if (_currentPeriodStart != null) {
        return Center(
          child: Text(
            '目前週期開始於：${DateFormat('yyyy/MM/dd').format(_currentPeriodStart!)}',
            style: const TextStyle(fontSize: 16),
          ),
        );
      }
      return const Center(
        child: Text('點擊右下角按鈕來記錄'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (record.hasPeriod) _buildPeriodCard(record),
        if (record.symptoms.values.any((v) => v)) _buildSymptomsCard(record),
        if (record.hasIntimacy) _buildIntimacyCard(record),
        if (record.notes?.isNotEmpty ?? false) _buildNotesCard(record),
      ],
    );
  }

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
          onPressed: () => _showAddRecordSheet(_selectedDay!, existingRecord: record),
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
        subtitle: Text(activeSymptoms.join(', ')),
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

  void _showAddRecordSheet(DateTime selectedDate, {DailyRecord? existingRecord}) {
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
            selectedDate: selectedDate,
            existingRecord: existingRecord,
            onSave: _handleRecordSave,
          ),
        );
      },
    );
  }

  Future<void> _handleRecordSave(DailyRecord record) async {
    try {
      await DatabaseService.instance.saveDailyRecord(record);
      await _loadEvents();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('儲存成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('儲存失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}