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
}
