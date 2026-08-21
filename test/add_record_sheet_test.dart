import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/services/database_service.dart';
import 'package:period_tracking/widgets/add_record_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('調整表單不會自動寫入，按儲存後只送出一次', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DatabaseService.instance.resetForTesting();
    final saved = <DailyRecord>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddRecordSheet(
            selectedDate: DateTime(2026, 8, 9),
            onSave: (record) async => saved.add(record),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '標記為經期'));
    await tester.pump();

    expect(saved, isEmpty);

    await tester.tap(find.byKey(const Key('save_record_button')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.hasPeriod, isTrue);
  });
}
