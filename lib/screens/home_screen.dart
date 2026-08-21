import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/daily_record.dart';
import '../providers/user_settings_provider.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../widgets/add_record_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = _dateOnly(DateTime.now());
  DateTime _selectedDay = _dateOnly(DateTime.now());
  Map<DateTime, DailyRecord> _events = <DateTime, DailyRecord>{};
  Set<DateTime> _predictedPeriodDays = <DateTime>{};
  List<DateTime> _predictedStarts = <DateTime>[];
  DateTime? _lastPeriodStart;
  int? _predictionConfidence;
  bool _isLoading = true;
  int _loadToken = 0;
  bool _rangeMode = false;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
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
      _loadEvents();
    }
  }

  @override
  void dispose() {
    DatabaseService.instance.revision.removeListener(_handleDataChanged);
    _settingsProvider?.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() => _loadEvents();

  Future<void> _loadEvents() async {
    final token = ++_loadToken;
    if (mounted && _events.isEmpty) setState(() => _isLoading = true);

    final records = await DatabaseService.instance.getAllDailyRecords();
    if (!mounted || token != _loadToken) return;
    final settings = context.read<UserSettingsProvider>().settings;
    final periodDetails = PredictionService.findPeriodDetails(records);
    final predictions = PredictionService.predictNextPeriods(records, settings);
    final averagePeriodLength = periodDetails.isEmpty
        ? settings.periodLength
        : (periodDetails.map((period) => period.$2).reduce((a, b) => a + b) /
                periodDetails.length)
            .round();
    final predictionDays = <DateTime>{};
    for (final start in predictions) {
      for (var offset = 0; offset < averagePeriodLength; offset++) {
        predictionDays.add(_dateOnly(start.add(Duration(days: offset))));
      }
    }

    setState(() {
      _events = <DateTime, DailyRecord>{
        for (final record in records) _dateOnly(record.date): record,
      };
      _predictedPeriodDays = predictionDays;
      _predictedStarts = predictions;
      _lastPeriodStart = periodDetails.isEmpty ? null : periodDetails.last.$1;
      _predictionConfidence =
          PredictionService.getPredictionConfidence(records);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LunaCare'),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _rangeMode ? Colors.pink[200] : null,
            ),
            tooltip: '範圍選擇模式',
            onPressed: () {
              setState(() {
                _rangeMode = !_rangeMode;
                if (!_rangeMode) {
                  _rangeStart = null;
                  _rangeEnd = null;
                }
              });
              if (_rangeMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請選擇經期起始日與結束日')),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: _buildStatusCard(),
                  ),
                  _buildCalendar(),
                  _buildLegend(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _buildSelectedDayCard(),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRecordSheet(_selectedDay),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('記錄這一天'),
      ),
    );
  }

  Widget _buildStatusCard() {
    final colors = Theme.of(context).colorScheme;
    if (_lastPeriodStart == null) {
      return Card(
        color: colors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '先記下最近一次經期',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '有了第一筆經期日期後，才會顯示個人化預估；目前不會用今天自動猜測。',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _pickFirstPeriodDate,
                icon: const Icon(Icons.calendar_month),
                label: const Text('選擇日期'),
              ),
            ],
          ),
        ),
      );
    }

    final next = _predictedStarts.isEmpty ? null : _predictedStarts.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.water_drop_outlined, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  '你的週期摘要',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: <Widget>[
                _StatusValue(
                  label: '最近一次開始',
                  value: DateFormat('yyyy/MM/dd').format(_lastPeriodStart!),
                ),
                if (next != null)
                  _StatusValue(
                    label: '下次預估',
                    value: DateFormat('yyyy/MM/dd').format(next),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 18, color: colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _predictionConfidence == null
                        ? '目前依你的週期設定估算；至少記錄 3 次經期開始日後，才會顯示可信度。'
                        : '依過去週期規律性估算，預測可信度 ${_predictionConfidence!}%。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    return TableCalendar<void>(
      locale: 'zh_TW',
      firstDay: DateTime(now.year - 10),
      lastDay: DateTime(now.year + 10, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      availableCalendarFormats: const <CalendarFormat, String>{
        CalendarFormat.month: '月',
        CalendarFormat.twoWeeks: '兩週',
        CalendarFormat.week: '週',
      },
      rangeSelectionMode: _rangeMode
          ? RangeSelectionMode.toggledOn
          : RangeSelectionMode.toggledOff,
      rangeStartDay: _rangeStart,
      rangeEndDay: _rangeEnd,
      onDaySelected: _rangeMode
          ? null
          : (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = _dateOnly(selectedDay);
                _focusedDay = focusedDay;
              });
            },
      onRangeSelected: (start, end, focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _rangeStart = start;
          _rangeEnd = end;
        });
        if (start != null && end != null) {
          _confirmAddPeriodRange(start, end);
        }
      },
      onFormatChanged: (format) => setState(() => _calendarFormat = format),
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      calendarBuilders: CalendarBuilders<void>(
        markerBuilder: (context, date, events) => _buildMarkers(date),
      ),
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        outsideDaysVisible: false,
      ),
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonShowsNext: false,
      ),
    );
  }

  Widget? _buildMarkers(DateTime date) {
    final normalized = _dateOnly(date);
    final record = _events[normalized];
    final colors = <Color>[];
    if (record?.hasPeriod ?? false) {
      colors.add(Theme.of(context).colorScheme.primary);
    }
    if (_predictedPeriodDays.contains(normalized) &&
        !(record?.hasPeriod ?? false)) {
      colors.add(Theme.of(context).colorScheme.primary.withValues(alpha: 0.35));
    }
    if (record?.symptoms.values.any((value) => value) ?? false) {
      colors.add(Colors.orange);
    }
    if (record?.hasIntimacy ?? false) {
      colors.add(Colors.purple);
    }
    if (colors.isEmpty) return null;

    return Positioned(
      bottom: 3,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: colors.take(3).map((color) {
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: <Widget>[
          _LegendItem(color: Theme.of(context).colorScheme.primary, text: '經期'),
          _LegendItem(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            text: '預估',
          ),
          const _LegendItem(color: Colors.orange, text: '症狀'),
          const _LegendItem(color: Colors.purple, text: '性行為'),
        ],
      ),
    );
  }

  Widget _buildSelectedDayCard() {
    final record = _events[_selectedDay];
    final isPrediction = _predictedPeriodDays.contains(_selectedDay) &&
        !(record?.hasPeriod ?? false);
    final activeSymptoms = record?.symptoms.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList() ??
        <String>[];

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
                    DateFormat('M 月 d 日 EEEE', 'zh_TW').format(_selectedDay),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (record != null)
                  IconButton(
                    tooltip: '編輯記錄',
                    onPressed: () => _showAddRecordSheet(_selectedDay),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (record == null) ...<Widget>[
              Text(isPrediction ? '這天在預估經期範圍內，尚未有實際記錄。' : '這天尚未有記錄。'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showAddRecordSheet(_selectedDay),
                icon: const Icon(Icons.add),
                label: const Text('新增記錄'),
              ),
            ] else ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (record.hasPeriod)
                    Chip(
                      avatar: const Icon(Icons.water_drop, size: 18),
                      label: Text(
                        '經期 · ${_bleedingLevelToString(record.bleedingLevel)}',
                      ),
                    ),
                  if (record.painLevel != null)
                    Chip(label: Text('疼痛 ${record.painLevel}/10')),
                  if (activeSymptoms.isNotEmpty)
                    Chip(label: Text(activeSymptoms.join('、'))),
                  if (record.hasIntimacy)
                    Chip(label: Text('性行為 ${record.intimacyFrequency ?? 1} 次')),
                ],
              ),
              if (record.notes?.isNotEmpty ?? false) ...<Widget>[
                const SizedBox(height: 12),
                Text(record.notes!),
              ],
              if (!record.hasPeriod &&
                  activeSymptoms.isEmpty &&
                  !record.hasIntimacy &&
                  !(record.notes?.isNotEmpty ?? false))
                const Text('已儲存一筆空白日記錄。'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFirstPeriodDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: '選擇最近一次有經血的日期',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = _dateOnly(picked);
      _focusedDay = picked;
    });
    _showAddRecordSheet(picked, initialHasPeriod: true);
  }

  Future<void> _showAddRecordSheet(
    DateTime date, {
    bool initialHasPeriod = false,
  }) async {
    final normalized = _dateOnly(date);
    final existingRecord = _events[normalized];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: AddRecordSheet(
          selectedDate: normalized,
          existingRecord: existingRecord,
          initialHasPeriod: initialHasPeriod,
          onSave: DatabaseService.instance.saveDailyRecord,
          onDelete: existingRecord == null
              ? null
              : () async {
                  await DatabaseService.instance.deleteDailyRecord(normalized);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('記錄已刪除'),
                      action: SnackBarAction(
                        label: '復原',
                        onPressed: () {
                          DatabaseService.instance
                              .saveDailyRecord(existingRecord);
                        },
                      ),
                    ),
                  );
                },
        ),
      ),
    );
  }

  String _bleedingLevelToString(BleedingLevel? level) {
    switch (level) {
      case BleedingLevel.spotting:
        return '點滴';
      case BleedingLevel.light:
        return '少';
      case BleedingLevel.medium:
        return '中';
      case BleedingLevel.heavy:
        return '多';
      case BleedingLevel.none:
      case null:
        return '未填';
    }
  }

  Future<void> _confirmAddPeriodRange(DateTime start, DateTime end) async {
    final normalizedStart = _dateOnly(start);
    final normalizedEnd = _dateOnly(end);
    final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
    final formatter = DateFormat('yyyy/MM/dd');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('新增經期'),
          content: Text(
            '將 ${formatter.format(normalizedStart)} 至 '
            '${formatter.format(normalizedEnd)} 標記為經期？(共 $dayCount 天)',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('確認'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      setState(() {
        _rangeMode = false;
        _rangeStart = null;
        _rangeEnd = null;
      });
      return;
    }

    for (int i = 0; i < dayCount; i++) {
      final day = normalizedStart.add(Duration(days: i));
      final existing = _events[day];
      final DailyRecord toSave;
      if (existing != null) {
        toSave = existing.copyWith(
          hasPeriod: true,
          bleedingLevel: existing.bleedingLevel ?? BleedingLevel.medium,
        );
      } else {
        toSave = DailyRecord(
          date: day,
          hasPeriod: true,
          bleedingLevel: BleedingLevel.medium,
        );
      }
      await DatabaseService.instance.saveDailyRecord(toSave);
    }

    setState(() {
      _rangeMode = false;
      _rangeStart = null;
      _rangeEnd = null;
    });
    await _loadEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已新增 $dayCount 天經期記錄')),
      );
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
