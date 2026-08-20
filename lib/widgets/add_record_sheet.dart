import 'package:flutter/material.dart';

import '../models/daily_record.dart';
import '../services/database_service.dart';

class AddRecordSheet extends StatefulWidget {
  const AddRecordSheet({
    super.key,
    required this.selectedDate,
    required this.onSave,
    this.onDelete,
    this.existingRecord,
    this.initialHasPeriod = false,
  });

  final DateTime selectedDate;
  final DailyRecord? existingRecord;
  final bool initialHasPeriod;
  final Future<void> Function(DailyRecord record) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  DailyRecord? _loadedRecord;

  bool _hasPeriod = false;
  BleedingLevel _bleedingLevel = BleedingLevel.medium;
  int _painLevel = 0;
  final Map<String, bool> _symptoms = <String, bool>{
    '情緒變化': false,
    '乳房脹痛': false,
    '腰痛': false,
    '頭痛': false,
    '疲勞': false,
    '痘痘': false,
    '噁心': false,
    '食慾改變': false,
    '失眠': false,
    '腹脹': false,
  };
  bool _hasIntimacy = false;
  int _intimacyFrequency = 1;
  ContraceptionMethod _contraceptionMethod = ContraceptionMethod.none;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _intimacyNotesController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final record = widget.existingRecord ??
        await DatabaseService.instance.getDailyRecord(widget.selectedDate);
    if (!mounted) return;

    if (record != null) {
      _loadedRecord = record;
      _hasPeriod = record.hasPeriod;
      _bleedingLevel = record.bleedingLevel ?? BleedingLevel.medium;
      _painLevel = record.painLevel ?? 0;
      _symptoms.addAll(record.symptoms);
      _notesController.text = record.notes ?? '';
      _hasIntimacy = record.hasIntimacy;
      _intimacyFrequency = record.intimacyFrequency ?? 1;
      _contraceptionMethod =
          record.contraceptionMethod ?? ContraceptionMethod.none;
      _intimacyNotesController.text = record.intimacyNotes ?? '';
    } else {
      _hasPeriod = widget.initialHasPeriod;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _intimacyNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _attemptClose();
      },
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.92,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: <Widget>[
                            _buildPeriodSection(),
                            if (_hasPeriod) ...<Widget>[
                              const SizedBox(height: 12),
                              _buildBleedingLevelSection(),
                              const SizedBox(height: 12),
                              _buildPainLevelSection(),
                            ],
                            const SizedBox(height: 12),
                            _buildSymptomsSection(),
                            const SizedBox(height: 12),
                            _buildNotesSection(),
                            const SizedBox(height: 12),
                            _buildIntimacySection(),
                            if (_loadedRecord != null &&
                                widget.onDelete != null) ...<Widget>[
                              const SizedBox(height: 20),
                              _buildDeleteButton(),
                            ],
                          ],
                        ),
                ),
                if (!_isLoading) _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final date = widget.selectedDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _loadedRecord == null ? '新增記錄' : '編輯記錄',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.year} 年 ${date.month} 月 ${date.day} 日',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '關閉',
            onPressed: _isSaving ? null : _attemptClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildPeriodSection() {
    return _sectionCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('今天有經血'),
        subtitle: const Text('只標記這一天，不會自動補上其他日期'),
        value: _hasPeriod,
        onChanged: (value) {
          setState(() {
            _hasPeriod = value;
            _isDirty = true;
          });
        },
      ),
    );
  }

  Widget _buildBleedingLevelSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle('出血量'),
          const SizedBox(height: 12),
          SegmentedButton<BleedingLevel>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<BleedingLevel>>[
              ButtonSegment(value: BleedingLevel.spotting, label: Text('點滴')),
              ButtonSegment(value: BleedingLevel.light, label: Text('少')),
              ButtonSegment(value: BleedingLevel.medium, label: Text('中')),
              ButtonSegment(value: BleedingLevel.heavy, label: Text('多')),
            ],
            selected: <BleedingLevel>{_bleedingLevel},
            onSelectionChanged: (selection) {
              setState(() {
                _bleedingLevel = selection.first;
                _isDirty = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPainLevelSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _SectionTitle('疼痛程度')),
              Text('$_painLevel / 10'),
            ],
          ),
          Slider(
            value: _painLevel.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: _painLevel.toString(),
            onChanged: (value) {
              setState(() {
                _painLevel = value.round();
                _isDirty = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomsSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle('身體與情緒'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _symptoms.entries.map((entry) {
              return FilterChip(
                label: Text(entry.key),
                selected: entry.value,
                onSelected: (selected) {
                  setState(() {
                    _symptoms[entry.key] = selected;
                    _isDirty = true;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle('備註'),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: '記下今天的狀況（選填）'),
            onChanged: (_) => setState(() => _isDirty = true),
          ),
        ],
      ),
    );
  }

  Widget _buildIntimacySection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('性行為記錄'),
            subtitle: const Text('這項資料只儲存在你的裝置與私人備份'),
            value: _hasIntimacy,
            onChanged: (value) {
              setState(() {
                _hasIntimacy = value;
                _isDirty = true;
              });
            },
          ),
          if (_hasIntimacy) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Expanded(child: Text('次數')),
                IconButton.filledTonal(
                  tooltip: '減少',
                  onPressed: _intimacyFrequency > 1
                      ? () => setState(() {
                            _intimacyFrequency--;
                            _isDirty = true;
                          })
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$_intimacyFrequency',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '增加',
                  onPressed: _intimacyFrequency < 20
                      ? () => setState(() {
                            _intimacyFrequency++;
                            _isDirty = true;
                          })
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ContraceptionMethod>(
              initialValue: _contraceptionMethod,
              decoration: const InputDecoration(labelText: '避孕方式'),
              items: ContraceptionMethod.values.map((method) {
                return DropdownMenuItem<ContraceptionMethod>(
                  value: method,
                  child: Text(_contraceptionMethodToString(method)),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _contraceptionMethod = value;
                  _isDirty = true;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _intimacyNotesController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: '相關備註（選填）'),
              onChanged: (_) => setState(() => _isDirty = true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _confirmDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('刪除這天的記錄'),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _attemptClose,
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              key: const Key('save_record_button'),
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? '儲存中' : '儲存記錄'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_hasPeriod &&
        !_hasIntimacy &&
        !_symptoms.values.any((value) => value) &&
        _notesController.text.trim().isEmpty &&
        _intimacyNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少選擇一項內容再儲存。')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final record = DailyRecord(
      id: _loadedRecord?.id,
      date: widget.selectedDate,
      hasPeriod: _hasPeriod,
      bleedingLevel: _hasPeriod ? _bleedingLevel : null,
      painLevel: _hasPeriod ? _painLevel : null,
      symptoms: Map<String, bool>.from(_symptoms),
      hasIntimacy: _hasIntimacy,
      intimacyFrequency: _hasIntimacy ? _intimacyFrequency : null,
      contraceptionMethod: _hasIntimacy ? _contraceptionMethod : null,
      notes: _trimmedOrNull(_notesController.text),
      intimacyNotes: _trimmedOrNull(_intimacyNotesController.text),
    );

    try {
      await widget.onSave(record);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$error')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這天的記錄？'),
        content: const Text('刪除後無法復原。其他日期不會受到影響。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.onDelete == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onDelete!();
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$error')),
      );
    }
  }

  Future<void> _attemptClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('放棄尚未儲存的變更？'),
        content: const Text('你剛剛調整的內容還沒有儲存。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('繼續編輯'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放棄變更'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _contraceptionMethodToString(ContraceptionMethod method) {
    switch (method) {
      case ContraceptionMethod.none:
        return '未使用';
      case ContraceptionMethod.condom:
        return '保險套';
      case ContraceptionMethod.pill:
        return '口服避孕藥';
      case ContraceptionMethod.iud:
        return '子宮內避孕器';
      case ContraceptionMethod.calendar:
        return '週期計算';
      case ContraceptionMethod.withdrawal:
        return '體外射精';
      case ContraceptionMethod.other:
        return '其他';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
