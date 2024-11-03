import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('設定'),
          ),
          body: ListView(
            children: [
              ListTile(
                title: const Text('週期長度'),
                subtitle: Text('${settings.cycleLength} 天'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCycleLengthDialog(context, settings),
              ),
              ListTile(
                title: const Text('經期長度'),
                subtitle: Text('${settings.periodLength} 天'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPeriodLengthDialog(context, settings),
              ),
              ListTile(
                title: const Text('提醒時間'),
                subtitle: Text(
                  '${settings.reminderTime.hour.toString().padLeft(2, '0')}:'
                  '${settings.reminderTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTime(context, settings),
              ),
              SwitchListTile(
                title: const Text('啟用通知'),
                value: settings.notificationsEnabled,
                onChanged: (bool value) {
                  settings.toggleNotifications(value);
                },
              ),
            ],
          ),
        );
      },
    );
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
    );
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
    );
  }
}