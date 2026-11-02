import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_record.dart';
import '../services/period_range_service.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart' as date_utils;

/// Sets a period's first and last day instead of marking each day. Pops with
/// the [PeriodRangeChange] to apply, or null when cancelled.
class PeriodRangeSheet extends StatefulWidget {
  const PeriodRangeSheet({
    super.key,
    required this.records,
    required this.initialStart,
    required this.typicalLength,
    this.editing,
    this.today,
  });

  final List<DailyRecord> records;

  /// First day suggested for a new period; ignored when [editing].
  final DateTime initialStart;

  /// Suggested length of a new period, in days.
  final int typicalLength;

  /// The recorded period being changed; null for a new one.
  final PeriodRange? editing;

  @visibleForTesting
  final DateTime? today;

  @override
  State<PeriodRangeSheet> createState() => _PeriodRangeSheetState();
}

class _PeriodRangeSheetState extends State<PeriodRangeSheet> {
  late final DateTime _today =
      date_utils.DateUtils.dateOnly(widget.today ?? DateTime.now());
  late DateTime _start;
  late DateTime _end;

  /// Until the user picks an end date, it follows the start date.
  bool _endPicked = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _start = editing.start;
      _end = editing.end;
      _endPicked = true;
    } else {
      _start = _clampToToday(widget.initialStart);
      _end = _suggestedEnd(_start);
    }
  }

  DateTime _clampToToday(DateTime date) {
    final day = date_utils.DateUtils.dateOnly(date);
    return day.isAfter(_today) ? _today : day;
  }

  DateTime _suggestedEnd(DateTime start) => _clampToToday(
        date_utils.DateUtils.addDays(start, max(widget.typicalLength, 1) - 1),
      );

  PeriodRange get _requested => PeriodRange(_start, _end);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requested = _requested;
    final merged = PeriodRangeService.plan(
      widget.records,
      previous: widget.editing,
      requested: requested,
    ).range!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.editing == null ? '新增經期' : '調整經期日期',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '選好第一天和最後一天，中間每天都會標記為經期。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _DateField(label: '開始日期', date: _start, onTap: _pickStart),
            const SizedBox(height: 8),
            _DateField(label: '結束日期', date: _end, onTap: _pickEnd),
            const SizedBox(height: 12),
            Text(
              '共 ${requested.length} 天',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (merged != requested) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '和相鄰的經期只差幾天，會合併為 ${formatPeriodRange(merged)}，'
                '共 ${merged.length} 天。',
              ),
            ],
            if (requested.length > AppConstants.maxPeriodLength) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '超過 ${AppConstants.maxPeriodLength} 天，請確認日期是否正確。',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_end == _today) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '經期還沒結束的話，之後再回來把結束日期改成實際的最後一天。',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                if (widget.editing != null)
                  TextButton.icon(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('刪除這次經期'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    PeriodRangeService.plan(
                      widget.records,
                      previous: widget.editing,
                      requested: requested,
                    ),
                  ),
                  child: const Text('儲存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await _pickDate(
      initial: _start,
      first: DateTime(_today.year - 10),
      help: '選擇經期第一天',
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (!_endPicked) {
        _end = _suggestedEnd(picked);
      } else if (_end.isBefore(picked)) {
        _end = picked;
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDate(
      initial: _end,
      first: _start,
      help: '選擇經期最後一天',
    );
    if (picked == null) return;
    setState(() {
      _end = picked;
      _endPicked = true;
    });
  }

  Future<DateTime?> _pickDate({
    required DateTime initial,
    required DateTime first,
    required String help,
  }) async {
    // A period edited from the daily sheet may reach past today or the
    // picker's range; the picker asserts that its initial date is in range.
    final firstDate = first.isAfter(_today) ? _today : first;
    final initialDate = initial.isBefore(firstDate)
        ? firstDate
        : initial.isAfter(_today)
            ? _today
            : initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: _today,
      helpText: help,
    );
    return picked == null ? null : date_utils.DateUtils.dateOnly(picked);
  }

  Future<void> _delete() async {
    final editing = widget.editing!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這次經期？'),
        content: Text(
          '${formatPeriodRange(editing)} 的經期標記會移除；這些日子記下的症狀和備註會保留。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(
      PeriodRangeService.plan(widget.records, previous: editing),
    );
  }
}

/// "10/1 – 10/5", with years when the period isn't in the current year.
String formatPeriodRange(PeriodRange range, {DateTime? today}) {
  final year = (today ?? DateTime.now()).year;
  final format = range.start.year == year && range.end.year == year
      ? DateFormat('M/d')
      : DateFormat('yyyy/M/d');
  return '${format.format(range.start)} – ${format.format(range.end)}';
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Icon(Icons.event_outlined, color: colors.primary),
      title: Text(label),
      trailing: Text(
        DateFormat('yyyy/M/d（E）', 'zh_TW').format(date),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: onTap,
    );
  }
}
