// lib/widgets/add_record_sheet.dart
import 'package:flutter/material.dart';
import '../models/daily_record.dart';
import '../services/database_service.dart';

class AddRecordSheet extends StatefulWidget {
  final DateTime selectedDate;
  final DailyRecord? existingRecord;
  final Function(DailyRecord) onSave;
  final VoidCallback onDelete;  // 新增刪除回調

  const AddRecordSheet({
    Key? key,
    required this.selectedDate,
    required this.onSave,
    required this.onDelete,  // 新增參數
    this.existingRecord,
  }) : super(key: key);

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  bool _hasPeriod = false;
  BleedingLevel _bleedingLevel = BleedingLevel.medium;
  int _painLevel = 0;
  final Map<String, bool> _symptoms = {
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
  final TextEditingController _intimacyNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final existingRecord = widget.existingRecord ??
        await DatabaseService.instance.getDailyRecord(widget.selectedDate);

    bool fallbackHasPeriod = false;
    if (existingRecord == null) {
      fallbackHasPeriod =
          await DatabaseService.instance.isInPeriod(widget.selectedDate);
    }

    if (!mounted) return;
    setState(() {
      if (existingRecord != null) {
        _hasPeriod = existingRecord.hasPeriod;
        _bleedingLevel = existingRecord.bleedingLevel ?? BleedingLevel.medium;
        _painLevel = existingRecord.painLevel ?? 0;
        _symptoms.addAll(existingRecord.symptoms);
        _notesController.text = existingRecord.notes ?? '';

        if (existingRecord.hasIntimacy) {
          _hasIntimacy = true;
          _intimacyFrequency = existingRecord.intimacyFrequency ?? 0;
          _contraceptionMethod =
              existingRecord.contraceptionMethod ?? ContraceptionMethod.none;
          _intimacyNotesController.text = existingRecord.intimacyNotes ?? '';
        }
      } else {
        _hasPeriod = fallbackHasPeriod;
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _intimacyNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Text(
                  widget.existingRecord != null ? '編輯記錄' : '新增記錄',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildPeriodSection(),
                const SizedBox(height: 16),

                if (_hasPeriod) ...[
                  _buildBleedingLevelSection(),
                  const SizedBox(height: 16),

                  _buildPainLevelSection(),
                  const SizedBox(height: 16),
                ],

                _buildSymptomsSection(),
                const SizedBox(height: 16),

                _buildNotesSection(),
                const SizedBox(height: 16),

                _buildIntimacySection(),
                const SizedBox(height: 24),

                // 刪除按鈕移到最底部
                if (widget.existingRecord != null)
                  Center(child: _buildDeleteButton()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 修改儲存方法
  Future<void> _handleSave() async {
    try {
      final record = DailyRecord(
        id: widget.existingRecord?.id,
        date: widget.selectedDate,
        hasPeriod: _hasPeriod,
        bleedingLevel: _hasPeriod ? _bleedingLevel : null,
        painLevel: _hasPeriod ? _painLevel : null,
        symptoms: Map<String, bool>.from(_symptoms),
        hasIntimacy: _hasIntimacy,
        intimacyFrequency: _hasIntimacy ? _intimacyFrequency : null,
        contraceptionMethod: _hasIntimacy ? _contraceptionMethod : null,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        intimacyNotes: _intimacyNotesController.text.isEmpty ? null : _intimacyNotesController.text,
      );

      await widget.onSave(record);
    } catch (e) {
      print('Error saving record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e')),
        );
      }
    }
  }
  
  Future<void> _togglePeriod() async {
    final wasOn = _hasPeriod;
    setState(() {
      _hasPeriod = !wasOn;
    });
    await _handleSave();
    if (wasOn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已標記為經期結束')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildPeriodSection() {
    final bool active = _hasPeriod;
    return Card(
      color: active ? Colors.pink.shade50 : null,
      child: InkWell(
        onTap: _togglePeriod,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                active ? Icons.water_drop : Icons.water_drop_outlined,
                color: Colors.pink,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '月經狀態',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active ? '來潮中' : '未記錄',
                      style: TextStyle(
                        fontSize: 14,
                        color: active ? Colors.pink.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              active
                  ? OutlinedButton(
                      onPressed: _togglePeriod,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.pink,
                        side: const BorderSide(color: Colors.pink),
                      ),
                      child: const Text('結束經期'),
                    )
                  : FilledButton(
                      onPressed: _togglePeriod,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.pink,
                      ),
                      child: const Text('標記為經期'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBleedingLevelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '出血量',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<BleedingLevel>(
              segments: const [
                ButtonSegment<BleedingLevel>(
                  value: BleedingLevel.light,
                  label: Text('少'),
                ),
                ButtonSegment<BleedingLevel>(
                  value: BleedingLevel.medium,
                  label: Text('中'),
                ),
                ButtonSegment<BleedingLevel>(
                  value: BleedingLevel.heavy,
                  label: Text('多'),
                ),
              ],
              selected: {_bleedingLevel},
              onSelectionChanged: (Set<BleedingLevel> newSelection) {
                setState(() {
                  _bleedingLevel = newSelection.first;
                });
                _handleSave();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPainLevelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '經痛程度',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                });
                _handleSave();
              },
            ),
            Center(
              child: Text(
                '${_painLevel.toString()} / 10',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '症狀',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _symptoms.keys.map((symptom) {
                return FilterChip(
                  label: Text(symptom),
                  selected: _symptoms[symptom]!,
                  onSelected: (bool selected) {
                    setState(() {
                      _symptoms[symptom] = selected;
                    });
                    _handleSave();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '備註',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '輸入備註...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _handleSave(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntimacySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '愛愛',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: _hasIntimacy,
                  onChanged: (value) {
                    setState(() {
                      _hasIntimacy = value;
                    });
                    _handleSave();
                  },
                ),
              ],
            ),
            if (_hasIntimacy) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('次數：'),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _intimacyFrequency > 1
                        ? () {
                            setState(() {
                              _intimacyFrequency--;
                            });
                            _handleSave();
                          }
                        : null,
                  ),
                  Text(
                    _intimacyFrequency.toString(),
                    style: const TextStyle(fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _intimacyFrequency++;
                      });
                      _handleSave();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ContraceptionMethod>(
                decoration: const InputDecoration(
                  labelText: '避孕方式',
                  border: OutlineInputBorder(),
                ),
                value: _contraceptionMethod,
                items: ContraceptionMethod.values.map((method) {
                  return DropdownMenuItem<ContraceptionMethod>(
                    value: method,
                    child: Text(_contraceptionMethodToString(method)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _contraceptionMethod = value;
                    });
                    _handleSave();
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _intimacyNotesController,
                decoration: const InputDecoration(
                  labelText: '備註',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (_) => _handleSave(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: ElevatedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認刪除'),
            content: const Text('確定要刪除這天的記錄嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  '刪除',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        
        if (confirmed == true) {
          widget.onDelete();  // 使用傳入的刪除回調
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: const BorderSide(color: Colors.red),
      ),
      icon: const Icon(Icons.delete_outline),
      label: const Text('刪除記錄'),
    ),
  );
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