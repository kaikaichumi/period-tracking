// lib/widgets/add_record_sheet.dart
import 'package:flutter/material.dart';
import '../models/daily_record.dart';
import '../services/database_service.dart';

class AddRecordSheet extends StatefulWidget {
  final DateTime selectedDate;
  final DailyRecord? existingRecord;
  final Function(DailyRecord) onSave;

  const AddRecordSheet({
    Key? key,
    required this.selectedDate,
    required this.onSave,
    this.existingRecord,
  }) : super(key: key);

  @override
  State<AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<AddRecordSheet> {
  // 月經相關
  bool _hasPeriod = false;
  BleedingLevel _bleedingLevel = BleedingLevel.medium;
  int _painLevel = 1;
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
  
  // 親密關係相關
  bool _hasIntimacy = false;
  int _intimacyFrequency = 1;
  ContraceptionMethod _contraceptionMethod = ContraceptionMethod.none;
  
  // 備註控制器
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _intimacyNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 檢查是否有現有記錄
    var existingRecord = widget.existingRecord ?? 
        await DatabaseService.instance.getDailyRecord(widget.selectedDate);
    
    if (existingRecord != null) {
      setState(() {
        _hasPeriod = existingRecord.hasPeriod;
        _bleedingLevel = existingRecord.bleedingLevel ?? BleedingLevel.medium;
        _painLevel = existingRecord.painLevel ?? 1;
        _symptoms.addAll(existingRecord.symptoms);
        _notesController.text = existingRecord.notes ?? '';
        
        if (existingRecord.hasIntimacy) {
          _hasIntimacy = true;
          _intimacyFrequency = existingRecord.intimacyFrequency ?? 1;
          _contraceptionMethod = existingRecord.contraceptionMethod ?? ContraceptionMethod.none;
          _intimacyNotesController.text = existingRecord.intimacyNotes ?? '';
        }
      });
    } else {
      // 如果沒有現有記錄，檢查是否在經期內
      var lastPeriodStart = await DatabaseService.instance.findLastPeriodStartDate();
          
      if (lastPeriodStart != null) {
        // 檢查是否有之後的結束記錄
        var records = await DatabaseService.instance.getAllDailyRecords();
        var endRecord = records
            .where((r) => !r.hasPeriod && 
                        r.date.isAfter(lastPeriodStart) && 
                        r.date.isBefore(widget.selectedDate))
            .toList();
            
        if (endRecord.isEmpty) {
          // 如果沒有結束記錄，且當前日期在經期開始日期之後
          if (widget.selectedDate.isAfter(lastPeriodStart)) {
            setState(() {
              _hasPeriod = true;  // 預設為經期中
            });
          }
        }
      }
    }
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
          _buildDragHandle(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  widget.existingRecord != null ? '編輯記錄' : '新增記錄',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

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

                Center(child: _buildSaveButton()),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPeriodSection() {
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
                  '月經來了',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: _hasPeriod,
                  onChanged: (value) {
                    setState(() {
                      _hasPeriod = value;
                    });
                  },
                ),
              ],
            ),
          ],
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
                  label: Text('輕'),
                ),
                ButtonSegment<BleedingLevel>(
                  value: BleedingLevel.medium,
                  label: Text('中'),
                ),
                ButtonSegment<BleedingLevel>(
                  value: BleedingLevel.heavy,
                  label: Text('重'),
                ),
              ],
              selected: {_bleedingLevel},
              onSelectionChanged: (Set<BleedingLevel> newSelection) {
                setState(() {
                  _bleedingLevel = newSelection.first;
                });
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
              min: 1,
              max: 10,
              divisions: 9,
              label: _painLevel.toString(),
              onChanged: (value) {
                setState(() {
                  _painLevel = value.round();
                });
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
                  '親密關係記錄',
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
              ),
            ],
          ],
        ),
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

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 12,
        ),
      ),
      child: const Text('儲存'),
    );
  }

  void _save() {
    try {
      final dailyRecord = DailyRecord(
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

      widget.onSave(dailyRecord);
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