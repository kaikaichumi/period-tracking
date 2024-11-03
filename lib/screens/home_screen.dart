import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/database_service.dart';
import '../models/period_record.dart';
import '../widgets/add_record_sheet.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PeriodRecord>> _events = {};
  bool _isLoading = false;
  PeriodRecord? _unfinishedRecord;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final records = await DatabaseService.instance.getAllPeriods();
      
      // 找到未完成的記錄（有開始日期但沒有結束日期的記錄）
      _unfinishedRecord = null;  // 重置未完成記錄
      for (var record in records) {
        if (record.endDate == null) {
          _unfinishedRecord = record;
          break;
        }
      }

      final Map<DateTime, List<PeriodRecord>> newEvents = {};
      for (final record in records) {
        DateTime current = record.startDate;
        final endDate = record.endDate ?? record.startDate;
        
        while (current.isBefore(endDate.add(const Duration(days: 1)))) {
          final date = DateTime(current.year, current.month, current.day);
          if (newEvents[date] == null) {
            newEvents[date] = [];
          }
          newEvents[date]!.add(record);
          current = current.add(const Duration(days: 1));
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
              return _events[DateTime(day.year, day.month, day.day)] ?? [];
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
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.pink[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.pink,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.pink[100],
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
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

  Widget _buildEventList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedDate = _selectedDay ?? _focusedDay;
    final events = _events[DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    )] ?? [];

    if (events.isEmpty) {
      if (_unfinishedRecord != null) {
        return Center(
          child: Text(
            '目前週期開始於：${DateFormat('yyyy/MM/dd').format(_unfinishedRecord!.startDate)}',
            style: const TextStyle(fontSize: 16),
          ),
        );
      }
      return const Center(
        child: Text('點擊右下角按鈕來記錄'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final record = events[index];
        return Card(
          child: ListTile(
            title: Text(
              '週期記錄',
              style: TextStyle(
                color: Colors.pink[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('開始：${DateFormat('yyyy/MM/dd').format(record.startDate)}'),
                if (record.endDate != null)
                  Text('結束：${DateFormat('yyyy/MM/dd').format(record.endDate!)}'),
                Text('經痛程度：${record.painLevel}/10'),
                Text('出血量：${_flowIntensityToString(record.flowIntensity)}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showAddRecordSheet(selectedDate, existingRecord: record),
            ),
          ),
        );
      },
    );
  }

  String _flowIntensityToString(FlowIntensity intensity) {
    switch (intensity) {
      case FlowIntensity.light:
        return '輕';
      case FlowIntensity.medium:
        return '中';
      case FlowIntensity.heavy:
        return '重';
    }
  }

  void _showAddRecordSheet(DateTime selectedDate, {PeriodRecord? existingRecord}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final recordToEdit = existingRecord ?? 
          (_unfinishedRecord != null ? _unfinishedRecord!.copyWith(endDate: selectedDate) : null);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AddRecordSheet(
            selectedDate: selectedDate,
            existingRecord: recordToEdit,
            onSave: _handleRecordSave,
          ),
        );
      },
    );
  }
  // 新增處理保存的方法
  Future<void> _handleRecordSave(PeriodRecord record) async {
    try {
      if (record.id != null) {
        await DatabaseService.instance.updatePeriod(record);
      } else {
        await DatabaseService.instance.insertPeriod(record);
      }
      
      // 重新載入資料
      await _loadEvents();
      
      // 先關閉 bottom sheet
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('儲存成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 顯示錯誤訊息
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