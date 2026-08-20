import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_settings_provider.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBusy = false;
  bool _isCheckingSignIn = true;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _refreshSignInState();
  }

  Future<void> _refreshSignInState() async {
    final signedIn = await BackupService.instance.isSignedIn();
    if (!mounted) return;
    setState(() {
      _isSignedIn = signedIn;
      _isCheckingSignIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UserSettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              _section(
                title: '週期設定',
                icon: Icons.calendar_month_outlined,
                children: <Widget>[
                  ListTile(
                    title: const Text('平均週期長度'),
                    subtitle: const Text('從一次經期開始到下一次開始'),
                    trailing: Text('${settings.cycleLength} 天'),
                    onTap: _isBusy ? null : () => _editCycleLength(settings),
                  ),
                  ListTile(
                    title: const Text('平均經期長度'),
                    subtitle: const Text('一次經期通常持續的天數'),
                    trailing: Text('${settings.periodLength} 天'),
                    onTap: _isBusy ? null : () => _editPeriodLength(settings),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                title: '提醒',
                icon: Icons.notifications_none,
                children: <Widget>[
                  SwitchListTile(
                    title: const Text('經期預估提醒'),
                    subtitle: Text(
                      NotificationService.instance.isSupported
                          ? '只有在已有經期記錄時才會安排提醒'
                          : '目前平台不支援本機通知',
                    ),
                    value: settings.notificationsEnabled &&
                        NotificationService.instance.isSupported,
                    onChanged: _isBusy ||
                            !NotificationService.instance.isSupported
                        ? null
                        : (enabled) => _toggleNotifications(settings, enabled),
                  ),
                  if (settings.notificationsEnabled &&
                      NotificationService.instance.isSupported) ...<Widget>[
                    ListTile(
                      title: const Text('提醒時間'),
                      trailing: Text(settings.reminderTime.format(context)),
                      onTap: _isBusy ? null : () => _selectTime(settings),
                    ),
                    ListTile(
                      title: const Text('提醒日'),
                      subtitle: Text(_reminderDaysText(settings.reminderDays)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          _isBusy ? null : () => _selectReminderDays(settings),
                    ),
                    ListTile(
                      leading: const Icon(Icons.send_outlined),
                      title: const Text('傳送測試通知'),
                      onTap: _isBusy ? null : _sendTestNotification,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _section(
                title: '私人備份',
                icon: Icons.cloud_outlined,
                children: <Widget>[
                  ListTile(
                    title: const Text('Google Drive App Data'),
                    subtitle: Text(
                      _isCheckingSignIn
                          ? '正在檢查登入狀態…'
                          : _isSignedIn
                              ? '已登入；備份只會存放在此 App 的私人資料夾'
                              : '尚未登入 Google 帳號',
                    ),
                    trailing: _isCheckingSignIn
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isSignedIn
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isBusy || !_isSignedIn
                                ? null
                                : () => _backup(settings),
                            icon: const Icon(Icons.backup_outlined),
                            label: const Text('建立備份'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isBusy || !_isSignedIn
                                ? null
                                : () => _restore(settings),
                            icon: const Icon(Icons.restore),
                            label: const Text('還原最新'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      _isSignedIn ? Icons.logout : Icons.login,
                    ),
                    title: Text(_isSignedIn ? '登出 Google 帳號' : '登入 Google 帳號'),
                    onTap: _isBusy || _isCheckingSignIn
                        ? null
                        : _toggleGoogleSignIn,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _section(
                title: '資料與隱私',
                icon: Icons.lock_outline,
                children: <Widget>[
                  const ListTile(
                    title: Text('資料儲存方式'),
                    subtitle: Text(
                      '每日記錄預設只保存在這台裝置。只有你主動建立備份時，才會上傳到 Google Drive 的 App 私人資料夾。',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('重設所有設定'),
                    subtitle: const Text('不會刪除每日記錄'),
                    onTap: _isBusy ? null : () => _resetSettings(settings),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      '刪除裝置上的所有記錄',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    subtitle: const Text('此操作無法復原；雲端備份不會被刪除'),
                    onTap: _isBusy ? null : _clearAllRecords,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '週期預估僅供自我觀察，不是避孕工具，也不能取代醫療診斷。若有異常出血、劇烈疼痛或其他疑慮，請尋求專業醫療協助。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (_isBusy) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: <Widget>[
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Future<void> _editCycleLength(UserSettingsProvider settings) async {
    final value = await _showNumberDialog(
      title: '平均週期長度',
      initialValue: settings.cycleLength,
      min: AppConstants.minCycleLength,
      max: AppConstants.maxCycleLength,
      helperText:
          '請輸入 ${AppConstants.minCycleLength}–${AppConstants.maxCycleLength} 天',
    );
    if (value != null) await _run(() => settings.updateCycleLength(value));
  }

  Future<void> _editPeriodLength(UserSettingsProvider settings) async {
    final value = await _showNumberDialog(
      title: '平均經期長度',
      initialValue: settings.periodLength,
      min: 1,
      max: 10,
      helperText: '請輸入 1–10 天',
    );
    if (value != null) await _run(() => settings.updatePeriodLength(value));
  }

  Future<int?> _showNumberDialog({
    required String title,
    required int initialValue,
    required int min,
    required int max,
    required String helperText,
  }) async {
    final controller = TextEditingController(text: initialValue.toString());
    String? errorText;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '天數',
              suffixText: '天',
              helperText: helperText,
              errorText: errorText,
            ),
            onSubmitted: (_) {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < min || value > max) {
                setDialogState(() => errorText = helperText);
              } else {
                Navigator.pop(dialogContext, value);
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value < min || value > max) {
                  setDialogState(() => errorText = helperText);
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _toggleNotifications(
    UserSettingsProvider settings,
    bool enabled,
  ) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        _showMessage('未取得通知權限，提醒未開啟。');
        return;
      }
    }
    await _run(
      () => settings.updateNotificationsEnabled(enabled),
      successMessage: enabled ? '提醒已開啟' : '提醒已關閉',
    );
  }

  Future<void> _selectTime(UserSettingsProvider settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (picked != null) await _run(() => settings.updateReminderTime(picked));
  }

  Future<void> _selectReminderDays(UserSettingsProvider settings) async {
    final selected = Set<int>.from(settings.reminderDays);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('選擇提醒日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final option in const <(int, String)>[
                (7, '一週前'),
                (3, '三天前'),
                (1, '一天前'),
                (0, '當天'),
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.$2),
                  value: selected.contains(option.$1),
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked ?? false) {
                        selected.add(option.$1);
                      } else {
                        selected.remove(option.$1);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await _run(() => settings.updateReminderDays(result));
  }

  String _reminderDaysText(Set<int> days) {
    if (days.isEmpty) return '未選擇提醒日';
    const labels = <int, String>{0: '當天', 1: '一天前', 3: '三天前', 7: '一週前'};
    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    return sorted.map((day) => labels[day]).whereType<String>().join('、');
  }

  Future<void> _sendTestNotification() async {
    final granted = await NotificationService.instance.checkPermissions();
    if (!granted) {
      _showMessage('系統通知權限目前未開啟。');
      return;
    }
    await _run(
      NotificationService.instance.showTestNotification,
      successMessage: '測試通知已送出',
    );
  }

  Future<void> _toggleGoogleSignIn() async {
    final signingIn = !_isSignedIn;
    await _run(() async {
      if (_isSignedIn) {
        await BackupService.instance.signOut();
      } else {
        await BackupService.instance.signIn();
      }
      await _refreshSignInState();
    }, successMessage: signingIn ? '已登入 Google 帳號' : '已登出 Google 帳號');
  }

  Future<void> _backup(UserSettingsProvider settings) async {
    final confirmed = await _confirm(
      title: '建立新的雲端備份？',
      message: '這會新增一份含目前每日記錄與設定的私人備份，不會覆蓋舊備份。',
      confirmText: '建立備份',
    );
    if (!confirmed) return;
    await _run(
      () => BackupService.instance.backup(settings),
      successMessage: '備份已建立',
    );
  }

  Future<void> _restore(UserSettingsProvider settings) async {
    final confirmed = await _confirm(
      title: '還原最新備份？',
      message: '成功驗證備份後，裝置上的每日記錄與設定會被替換。若過程失敗，原資料會保留。',
      confirmText: '還原',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      () => BackupService.instance.restore(settings),
      successMessage: '資料已還原',
    );
  }

  Future<void> _resetSettings(UserSettingsProvider settings) async {
    final confirmed = await _confirm(
      title: '重設所有設定？',
      message: '週期、經期長度與提醒設定會回到預設值；每日記錄不會刪除。',
      confirmText: '重設',
    );
    if (!confirmed) return;
    await _run(settings.resetToDefaults, successMessage: '設定已重設');
  }

  Future<void> _clearAllRecords() async {
    final confirmed = await _confirm(
      title: '永久刪除裝置上的所有記錄？',
      message: '這項操作無法復原。若你之後還原雲端備份，備份中的資料仍可回到裝置。',
      confirmText: '永久刪除',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      DatabaseService.instance.clearAllData,
      successMessage: '裝置上的每日記錄已刪除',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _run(
    Future<dynamic> Function() action, {
    String? successMessage,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      if (successMessage != null) _showMessage(successMessage);
    } on Object catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
