import 'package:flutter/material.dart';
import '../models/period_record.dart';
import '../models/intimacy_record.dart';
import '../utils/constants.dart';
import '../services/database_service.dart';

class AddRecordSheet extends StatefulWidget {
  final DateTime selectedDate;
  final Function(PeriodRecord) onSave;
  final PeriodRecord? existingRecord;

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
  late DateTime _startDate;
  DateTime? _endDate;
  int _painLevel = 1;
  FlowIntensity _flowIntensity = FlowIntensity.medium;
  final Map<String, bool> _symptoms = Map.fromEntries(
    AppConstants.symptoms.entries.map(
      (e) => MapEntry(e.value, false),
    ),
  );
  
  // 親密關係相關變數
  bool _hasIntimacy = false;
  int _intimacyFrequency = 1;
  ContraceptionMethod _selectedContraception = ContraceptionMethod.none;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _intimacyNotesController = TextEditingController();
  bool _isEditing = false;
  bool _isSettingEndDate = false;
  IntimacyRecord? _existingIntimacyRecord;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 初始化經期記錄
    if (widget.existingRecord != null) {
      setState(() {
        _startDate = widget.existingRecord!.startDate;
        _endDate = widget.existingRecord!.endDate;
        _painLevel = widget.existingRecord!.painLevel;
        _flowIntensity = widget.existingRecord!.flowIntensity;
        _symptoms.addAll(widget.existingRecord!.symptoms);
        _notesController.text = widget.existingRecord!.notes ?? '';
        _isEditing = true;
        _isSettingEndDate = widget.existingRecord!.endDate == null;
        if (_isSettingEndDate) {
          _endDate = widget.selectedDate;
        }
      });
    } else {
      _startDate = widget.selectedDate;
    }

    // 載入親密關係記錄
    try {
      _existingIntimacyRecord = await DatabaseService.instance
          .getIntimacyRecordForDate(widget.selectedDate);
      
      if (_existingIntimacyRecord != null) {
        setState(() {
          _hasIntimacy = true;
          _intimacyFrequency = _existingIntimacyRecord!.frequency;
          _selectedContraception = _existingIntimacyRecord!.contraceptionMethod;
          _intimacyNotesController.text = _existingIntimacyRecord!.notes ?? '';
        });
      }
    } catch (e) {
      print('Error loading intimacy record: $e');
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
    if (_isSettingEndDate) {
      return _buildEndDateSheet();
    }
    return _buildFullSheet();
  }

  Widget _buildEndDateSheet() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const Text(
            '設定結束日期',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('開始日期'),
            subtitle: Text('${_startDate.year}/${_startDate.month}/${_startDate.day}'),
            leading: const Icon(Icons.calendar_today),
            enabled: false,
          ),
          ListTile(
            title: const Text('結束日期'),
            subtitle: Text('${_endDate!.year}/${_endDate!.month}/${_endDate!.day}'),
            leading: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(false),
          ),
          const SizedBox(height: 16),
          Text(
            '週期長度：${_endDate!.difference(_startDate).inDays + 1} 天',
            style: TextStyle(
              color: Colors.pink[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildSaveButton('儲存結束日期'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFullSheet() {
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
                  _isEditing ? '編輯記錄' : '新增記錄',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildDateSection(),
                const SizedBox(height: 16),

                _buildPainLevelSection(),
                const SizedBox(height: 16),

                _buildFlowIntensitySection(),
                const SizedBox(height: 16),

                _buildSymptomsSection(),
                const SizedBox(height: 16),

                _buildNotesSection(),
                const SizedBox(height: 16),

                _buildIntimacySection(),
                const SizedBox(height: 24),

                Center(child: _buildSaveButton('儲存')),
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

  Widget _buildDateSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '週期日期',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('開始日期'),
              subtitle: Text(
                '${_startDate.year}/${_startDate.month}/${_startDate.day}',
              ),
              leading: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(true),
            ),
            if (_isEditing) ...[
              ListTile(
                title: const Text('結束日期（選填）'),
                subtitle: Text(
                  _endDate != null
                      ? '${_endDate!.year}/${_endDate!.month}/${_endDate!.day}'
                      : '請選擇結束日期',
                ),
                leading: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(false),
              ),
              if (_endDate != null)
                Center(
                  child: Text(
                    '週期長度：${_endDate!.difference(_startDate).inDays + 1} 天',
                    style: TextStyle(
                      color: Colors.pink[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
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

  Widget _buildFlowIntensitySection() {
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
            SegmentedButton<FlowIntensity>(
              segments: const [
                ButtonSegment<FlowIntensity>(
                  value: FlowIntensity.light,
                  label: Text('輕'),
                ),
                ButtonSegment<FlowIntensity>(
                  value: FlowIntensity.medium,
                  label: Text('中'),
                ),
                ButtonSegment<FlowIntensity>(
                  value: FlowIntensity.heavy,
                  label: Text('重'),
                ),
              ],
              selected: {_flowIntensity},
              onSelectionChanged: (Set<FlowIntensity> newSelection) {
                setState(() {
                  _flowIntensity = newSelection.first;
                });
              },
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

   // 修改親密關係記錄區塊的建構方法
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
                value: _selectedContraception,
                items: ContraceptionMethod.values.map((method) {
                  return DropdownMenuItem<ContraceptionMethod>(
                    value: method,
                    child: Text(_getContraceptionMethodText(method)),
                  );
                }).toList(),
                onChanged: (ContraceptionMethod? value) {
                  if (value != null) {
                    setState(() {
                      _selectedContraception = value;
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

  Widget _buildSaveButton(String text) {
    return ElevatedButton(
      onPressed: _savePeriod,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.pink,
        padding: const EdgeInsets.symmetric(horizontal: 32,
          vertical: 12,
        ),
      ),
      child: Text(text),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime currentDate = isStartDate ? _startDate : (_endDate ?? _startDate);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: isStartDate ? DateTime(2020) : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('zh', 'TW'),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // 如果選擇的開始日期在結束日期之後，清除結束日期
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // 避孕方式文字轉換輔助方法
  String _getContraceptionMethodText(ContraceptionMethod method) {
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

  // 修改保存方法
  void _savePeriod() async {
  try {
    // 保存經期記錄
    final periodRecord = PeriodRecord(
      id: widget.existingRecord?.id,
      startDate: _startDate,
      endDate: _endDate,
      painLevel: _painLevel,
      symptoms: Map<String, bool>.from(_symptoms),
      flowIntensity: _flowIntensity,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    // 使用回調保存經期記錄
    widget.onSave(periodRecord);

    // 如果有親密關係記錄，保存它
    if (_hasIntimacy) {
      final intimacyRecord = IntimacyRecord(
        id: _existingIntimacyRecord?.id,
        date: widget.selectedDate,
        frequency: _intimacyFrequency,
        contraceptionMethod: _selectedContraception,
        notes: _intimacyNotesController.text.isEmpty 
          ? null 
          : _intimacyNotesController.text,
      );
      await DatabaseService.instance.saveIntimacyRecord(intimacyRecord);
    } else if (_existingIntimacyRecord?.id != null) {
      // 如果原本有記錄但現在關閉了，刪除記錄
      await DatabaseService.instance.deleteIntimacyRecord(_existingIntimacyRecord!.id!);
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
    return; // 發生錯誤時不關閉表單
  }
}
}