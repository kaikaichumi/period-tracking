// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSettingsProvider>(
      builder: (context, settings, child) {
        return Column(
          children: [
            AppBar(
              title: const Text('設定'),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('預設週期長度'),
                    subtitle: Text('${settings.cycleLength} 天'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCycleLengthDialog(context, settings),
                  ),
                  ListTile(
                    title: const Text('預設經期長度'),
                    subtitle: Text('${settings.periodLength} 天'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showPeriodLengthDialog(context, settings),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('啟用通知'),
                    value: settings.notificationsEnabled,
                    onChanged: (bool value) {
                      settings.updateNotificationsEnabled(value);
                    },
                  ),
                  if (settings.notificationsEnabled) ...[
                    ListTile(
                      title: const Text('提醒時間'),
                      subtitle: Text(
                        '${settings.reminderTime.hour.toString().padLeft(2, '0')}:'
                        '${settings.reminderTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectTime(context, settings),
                    ),
                    ListTile(
                      title: const Text('提醒日期'),
                      subtitle: _buildReminderDaysText(settings.reminderDays),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showReminderDaysDialog(context, settings),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Text _buildReminderDaysText(Set<int> days) {
    if (days.isEmpty) return const Text('未設定');
    
    final List<String> descriptions = [];
    if (days.contains(7)) descriptions.add('一週前');
    if (days.contains(3)) descriptions.add('三天前');
    if (days.contains(1)) descriptions.add('一天前');
    if (days.contains(0)) descriptions.add('當天');
    
    return Text(descriptions.join('、'));
  }

  Future<void> _selectTime(BuildContext context, UserSettingsProvider settings) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (picked != null) {
      settings.updateReminderTime(picked);
    }
  }

  Future<void> _showCycleLengthDialog(
    BuildContext context,
    UserSettingsProvider settings,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: settings.cycleLength.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定週期長度'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '天數',
            suffix: Text('天'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newLength = int.tryParse(controller.text);
              if (newLength != null && newLength > 0) {
                settings.updateCycleLength(newLength);
              }
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _showPeriodLengthDialog(
    BuildContext context,
    UserSettingsProvider settings,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: settings.periodLength.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定經期長度'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '天數',
            suffix: Text('天'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newLength = int.tryParse(controller.text);
              if (newLength != null && newLength > 0) {
                settings.updatePeriodLength(newLength);
              }
              Navigator.pop(context);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _showReminderDaysDialog(
    BuildContext context,
    UserSettingsProvider settings,
  ) async {
    Set<int> selectedDays = Set.from(settings.reminderDays);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('選擇提醒時間'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('一週前'),
                value: selectedDays.contains(7),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      selectedDays.add(7);
                    } else {
                      selectedDays.remove(7);
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('三天前'),
                value: selectedDays.contains(3),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      selectedDays.add(3);
                    } else {
                      selectedDays.remove(3);
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('一天前'),
                value: selectedDays.contains(1),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      selectedDays.add(1);
                    } else {
                      selectedDays.remove(1);
                    }
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('當天'),
                value: selectedDays.contains(0),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      selectedDays.add(0);
                    } else {
                      selectedDays.remove(0);
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                settings.updateReminderDays(selectedDays);
                Navigator.pop(context);
              },
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );
  }
}