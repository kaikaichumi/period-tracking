import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/widgets/add_record_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness({DailyRecord? existing, required void Function(DailyRecord) onSave, void Function()? onDelete}) {
  return MaterialApp(
    home: Scaffold(
      body: AddRecordSheet(
        selectedDate: DateTime(2026, 5, 9),
        existingRecord: existing,
        onSave: onSave,
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AddRecordSheet period UI', () {
    testWidgets('shows "標記為經期" filled button when no record', (tester) async {
      DailyRecord? saved;
      await tester.pumpWidget(_harness(onSave: (r) => saved = r));
      await tester.pump();

      expect(find.text('月經狀態'), findsOneWidget);
      expect(find.text('未記錄'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '標記為經期'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '結束經期'), findsNothing);
      expect(saved, isNull);
    });

    testWidgets('respects existingRecord.hasPeriod == false (no override bug)', (tester) async {
      // Bug 1 regression test: an existing record with hasPeriod=false must
      // NOT have its toggle force-enabled by isInPeriod.
      final endDay = DailyRecord(
        date: DateTime(2026, 5, 9),
        hasPeriod: false,
        isPeriodEndDay: true,
      );
      await tester.pumpWidget(_harness(existing: endDay, onSave: (_) {}));
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
      await tester.pumpWidget(_harness(existing: periodDay, onSave: (_) {}));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('來潮中'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '結束經期'), findsOneWidget);
      expect(find.text('出血量'), findsOneWidget);
      expect(find.text('經痛程度'), findsOneWidget);
    });

    testWidgets('tapping "標記為經期" toggles state and triggers save', (tester) async {
      final saved = <DailyRecord>[];
      await tester.pumpWidget(_harness(onSave: saved.add));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '標記為經期'));
      await tester.pumpAndSettle();

      expect(saved, isNotEmpty);
      expect(saved.last.hasPeriod, isTrue);
      expect(find.text('來潮中'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '結束經期'), findsOneWidget);
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
