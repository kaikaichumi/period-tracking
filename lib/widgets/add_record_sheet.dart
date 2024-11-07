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
    // 獲取當前記錄
  var existingRecord = widget.existingRecord ?? 
      await DatabaseService.instance.getDailyRecord(widget.selectedDate);

  // 檢查當前選擇的日期是否在經期中
  final isInPeriod = await DatabaseService.instance.isInPeriod(widget.selectedDate);

  setState(() {
    if (existingRecord != null) {
      // 載入現有記錄
      _hasPeriod = existingRecord.hasPeriod;
      _bleedingLevel = existingRecord.bleedingLevel ?? BleedingLevel.medium;
      _painLevel = existingRecord.painLevel ?? 0;
      _symptoms.addAll(existingRecord.symptoms);
      _notesController.text = existingRecord.notes ?? '';
      
      if (existingRecord.hasIntimacy) {
        _hasIntimacy = true;
        _intimacyFrequency = existingRecord.intimacyFrequency ?? 0;
        _contraceptionMethod = existingRecord.contraceptionMethod ?? ContraceptionMethod.none;
        _intimacyNotesController.text = existingRecord.intimacyNotes ?? '';
      }
    }
    
    // 根據當前日期是否在經期中來設定開關狀態
    _hasPeriod = isInPeriod;
  });
}

    void _saveRecord() async {
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

    // 如果是同一天內從"是"改為"否"，不需要額外處理
    if (!_hasPeriod && widget.existingRecord?.hasPeriod == true) {
      if (mounted) {
        Navigator.of(context).pop();  // 確保會關閉視窗
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
  
  Widget _buildPeriodSection() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '大姨媽來了',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: _hasPeriod,
                  onChanged: (value) async {
                    setState(() {
                      _hasPeriod = value;
                    });
                    await _handleSave();
                    if (!value) {
                      // 關閉經期時關閉表單
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  activeColor: Colors.pink,
                ),
              ],
            ),
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
                _saveRecord();
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
                _saveRecord();
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
                    _saveRecord();
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
              onChanged: (_) => _saveRecord(),
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
                    _saveRecord();
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
                            _saveRecord();
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
                      _saveRecord();
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
                    _saveRecord();
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
                onChanged: (_) => _saveRecord(),
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