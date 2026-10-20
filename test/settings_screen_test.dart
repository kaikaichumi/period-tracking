import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:period_tracking/providers/user_settings_provider.dart';
import 'package:period_tracking/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('週期天數超出範圍時保留對話框並顯示錯誤', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = UserSettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<UserSettingsProvider>.value(
        value: settings,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('平均週期長度'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('儲存'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('請輸入 21–35 天'), findsWidgets);
    expect(settings.cycleLength, 28);

    await tester.enterText(find.byType(TextField), '30');
    await tester.tap(find.text('儲存'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(settings.cycleLength, 30);
  });

  testWidgets('Android 提供 Google Drive 備份，並說明不會自動備份', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      ChangeNotifierProvider<UserSettingsProvider>(
        create: (_) => UserSettingsProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('登入 Google 帳號'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('資料儲存方式'), 200);
    expect(find.textContaining('不會隨系統自動備份上傳'), findsOneWidget);
  });

  testWidgets('iOS 沒有 Google 用戶端 ID 時不提供登入，並說明 iCloud 備份', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      ChangeNotifierProvider<UserSettingsProvider>(
        create: (_) => UserSettingsProvider(),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('這個版本尚未提供雲端備份'), findsOneWidget);
    expect(find.text('登入 Google 帳號'), findsNothing);
    expect(find.text('建立備份'), findsNothing);
    await tester.scrollUntilVisible(find.text('資料儲存方式'), 200);
    expect(find.textContaining('iCloud 備份'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
