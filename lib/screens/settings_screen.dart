// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_settings_provider.dart';
import '../services/backup_service.dart';
import '../utils/constants.dart';

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
              centerTitle: true,
            ),
            Expanded(
              child: ListView(
                children: [
                  // 週期設定
                  _buildSection(
                    title: '週期設定',
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
                    ],
                  ),

                  // 通知設定
                  _buildSection(
                    title: '通知設定',
                    children: [
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
                          title: const Text('提醒時間點'),
                          subtitle: _buildReminderDaysText(settings.reminderDays),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showReminderDaysDialog(context, settings),
                        ),
                      ],
                    ],
                  ),

                  // 備份設定
                  _buildSection(
                    title: '備份設定',
                    children: [
                      ListTile(
                        title: const Text('Google 雲端備份'),
                        subtitle: FutureBuilder<bool>(
                          future: BackupService.instance.isSignedIn(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!) {
                              return const Text('已登入 Google 帳號');
                            }
                            return const Text('尚未登入 Google 帳號');
                          },
                        ),
                        trailing: const Icon(Icons.cloud),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.backup),
                                label: const Text('備份'),
                                onPressed: () => _handleBackup(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.restore),
                                label: const Text('還原'),
                                onPressed: () => _handleRestore(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () => _handleSignInOut(context),
                          child: FutureBuilder<bool>(
                            future: BackupService.instance.isSignedIn(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!) {
                                return const Text('登出 Google 帳號');
                              }
                              return const Text('登入 Google 帳號');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildReminderDaysText(Set<int> days) {
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
      await settings.updateReminderTime(picked);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '天數',
                suffix: Text('天'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '建議範圍：${AppConstants.minCycleLength}-${AppConstants.maxCycleLength} 天',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '天數',
                suffix: Text('天'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '建議範圍：3-7 天',
              style: TextStyle(color: Colors.grey, fontSize: 12),
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

  Future<void> _showReminderDaysDialog(
    BuildContext context,
    UserSettingsProvider settings,
  ) async {
    Set<int> selectedDays = Set.from(settings.reminderDays);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇提醒時間'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('一週前'),
              value: selectedDays.contains(7),
              onChanged: (checked) {
                if (checked ?? false) {
                  selectedDays.add(7);
                } else {
                  selectedDays.remove(7);
                }
                settings.updateReminderDays(selectedDays);
              },
            ),
            CheckboxListTile(
              title: const Text('三天前'),
              value: selectedDays.contains(3),
              onChanged: (checked) {
                if (checked ?? false) {
                  selectedDays.add(3);
                } else {
                  selectedDays.remove(3);
                }
                settings.updateReminderDays(selectedDays);
              },
            ),
            CheckboxListTile(
              title: const Text('一天前'),
              value: selectedDays.contains(1),
              onChanged: (checked) {
                if (checked ?? false) {
                  selectedDays.add(1);
                } else {
                  selectedDays.remove(1);
                }
                settings.updateReminderDays(selectedDays);
              },
            ),
            CheckboxListTile(
              title: const Text('當天'),
              value: selectedDays.contains(0),
              onChanged: (checked) {
                if (checked ?? false) {
                  selectedDays.add(0);
                } else {
                  selectedDays.remove(0);
                }
                settings.updateReminderDays(selectedDays);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignInOut(BuildContext context) async {
    try {
      final isSignedIn = await BackupService.instance.isSignedIn();
      if (isSignedIn) {
        await BackupService.instance.signOut();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已登出 Google 帳號')),
          );
        }
      } else {
        await BackupService.instance.signIn();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已登入 Google 帳號')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失敗: $e')),
        );
      }
    }
  }

  Future<void> _handleBackup(BuildContext context) async {
    try {
      final isSignedIn = await BackupService.instance.isSignedIn();
      if (!isSignedIn) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請先登入 Google 帳號')),
          );
        }
        return;
      }

      // 顯示確認對話框
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認備份'),
            content: const Text('這將會覆蓋雲端上的舊備份，確定要繼續嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確定'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      // 顯示進度指示
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      await BackupService.instance.backup();

      // 關閉進度指示
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('備份成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 關閉進度指示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('備份失敗: $e')),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    try {
      final isSignedIn = await BackupService.instance.isSignedIn();
      if (!isSignedIn) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('請先登入 Google 帳號')),
          );
        }
        return;
      }

      // 顯示確認對話框
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認還原'),
            content: const Text('這將會覆蓋本機上的所有資料，確定要繼續嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確定'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      // 顯示進度指示
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      await BackupService.instance.restore();

      // 關閉進度指示
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('還原成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 關閉進度指示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('還原失敗: $e')),
        );
      }
    }
  }
}

// 建議也添加一個確認視窗的通用組件
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;

  const ConfirmDialog({
    Key? key,
    required this.title,
    required this.content,
    this.cancelText = '取消',
    this.confirmText = '確定',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

// 建議也添加一個進度指示器組件
class LoadingDialog extends StatelessWidget {
  final String message;

  const LoadingDialog({
    Key? key,
    this.message = '處理中...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}