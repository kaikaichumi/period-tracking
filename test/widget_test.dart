import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:period_tracking/main.dart';
import 'package:period_tracking/providers/user_settings_provider.dart';
import 'package:period_tracking/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首次開啟顯示真實空狀態，不顯示虛構預測', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DatabaseService.instance.resetForTesting();

    await tester.pumpWidget(
      ChangeNotifierProvider<UserSettingsProvider>(
        create: (_) => UserSettingsProvider(),
        child: const MyApp(),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('先記下最近一次經期').evaluate().isNotEmpty) break;
    }

    expect(find.text('LunaCare'), findsOneWidget);
    expect(find.text('先記下最近一次經期'), findsOneWidget);
    expect(find.textContaining('50%'), findsNothing);
    expect(find.text('日曆'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
  });
}
