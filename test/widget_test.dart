import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:period_tracking/main.dart';
import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/providers/user_settings_provider.dart';
import 'package:period_tracking/services/database_service.dart';
import 'package:period_tracking/widgets/add_record_sheet.dart';

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

  group('AddRecordSheet period UI', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await DatabaseService.instance.resetForTesting();
    });

    testWidgets('no record shows 未記錄 and 標記為經期 filled button',
        (tester) async {
      DailyRecord? saved;
      await tester.pumpWidget(_sheetHarness(onSave: (record) async { saved = record; }));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('月經狀態'), findsOneWidget);
      expect(find.text('未記錄'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '標記為經期'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '結束經期'), findsNothing);
      expect(saved, isNull);
    });

    testWidgets('respects existingRecord.hasPeriod == false (no override)',
        (tester) async {
      final endDay = DailyRecord(
        date: DateTime(2026, 5, 9),
        hasPeriod: false,
        isPeriodEndDay: true,
      );
      await tester.pumpWidget(_sheetHarness(existing: endDay, onSave: (_) async {}));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('未記錄'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '標記為經期'), findsOneWidget);
    });

    testWidgets('respects existingRecord.hasPeriod == true', (tester) async {
      final periodDay = DailyRecord(
        date: DateTime(2026, 5, 9),
        hasPeriod: true,
        bleedingLevel: BleedingLevel.medium,
      );
      await tester.pumpWidget(_sheetHarness(existing: periodDay, onSave: (_) async {}));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('來潮中'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '結束經期'), findsOneWidget);
      expect(find.text('出血量'), findsOneWidget);
      expect(find.text('疼痛程度'), findsOneWidget);
    });

    testWidgets('標記為經期 toggles state, then 儲存記錄 saves', (tester) async {
      final saved = <DailyRecord>[];
      await tester.pumpWidget(_sheetHarness(onSave: (record) async { saved.add(record); }));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '標記為經期'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      expect(find.text('來潮中'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '結束經期'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save_record_button')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.hasPeriod, isTrue);
      expect(saved.single.bleedingLevel, BleedingLevel.medium);
    });
  });

  group('DailyRecord copyWith merge for range add', () {
    test('copyWith preserves bleedingLevel when only flipping hasPeriod', () {
      final base = DailyRecord(
        date: DateTime(2026, 5, 9),
        hasPeriod: false,
        bleedingLevel: BleedingLevel.heavy,
        painLevel: 7,
        notes: 'preserve me',
      );
      final merged = base.copyWith(
        hasPeriod: true,
        bleedingLevel: base.bleedingLevel ?? BleedingLevel.medium,
      );
      expect(merged.hasPeriod, isTrue);
      expect(merged.bleedingLevel, BleedingLevel.heavy);
      expect(merged.painLevel, 7);
      expect(merged.notes, 'preserve me');
    });

    test('range merge defaults bleedingLevel to medium when missing', () {
      final base = DailyRecord(date: DateTime(2026, 5, 9));
      final merged = base.copyWith(
        hasPeriod: true,
        bleedingLevel: base.bleedingLevel ?? BleedingLevel.medium,
      );
      expect(merged.hasPeriod, isTrue);
      expect(merged.bleedingLevel, BleedingLevel.medium);
    });
  });
}

Widget _sheetHarness({
  DailyRecord? existing,
  required Future<void> Function(DailyRecord) onSave,
  Future<void> Function()? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AddRecordSheet(
        selectedDate: DateTime(2026, 5, 9),
        existingRecord: existing,
        onSave: onSave,
        onDelete: onDelete ?? () async {},
      ),
    ),
  );
}
