import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/services/period_range_service.dart';
import 'package:period_tracking/widgets/period_range_sheet.dart';

void main() {
  DateTime nov(int day) => DateTime(2026, 11, day);

  /// Opens the sheet and returns a getter for what it popped with.
  Future<PeriodRangeChange? Function()> openSheet(
    WidgetTester tester, {
    List<DailyRecord> records = const <DailyRecord>[],
    PeriodRange? editing,
  }) async {
    PeriodRangeChange? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        supportedLocales: const <Locale>[Locale('zh', 'TW')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<PeriodRangeChange>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PeriodRangeSheet(
                    records: records,
                    editing: editing,
                    initialStart: nov(10),
                    typicalLength: 5,
                    today: nov(20),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('新經期預設長度取平常的天數，選好結束日後一次儲存整段', (tester) async {
    final result = await openSheet(tester);

    expect(find.text('新增經期'), findsOneWidget);
    expect(find.text('共 5 天'), findsOneWidget);
    expect(find.text('刪除這次經期'), findsNothing);

    await tester.tap(find.text('結束日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16'));
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(find.text('共 7 天'), findsOneWidget);

    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    final change = result()!;
    expect(change.range, PeriodRange(nov(10), nov(16)));
    expect(change.save, hasLength(7));
    expect(change.save.every((record) => record.hasPeriod), isTrue);
  });

  testWidgets('改了開始日，預設結束日會跟著移動，但不會超過今天', (tester) async {
    await openSheet(tester);

    // Today is 11/20, so a 5-day period starting 11/18 stops at 11/20.
    await tester.tap(find.text('開始日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('18'));
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.text('共 3 天'), findsOneWidget);
    expect(find.textContaining('經期還沒結束的話'), findsOneWidget);
  });

  testWidgets('調整中的經期可以整段刪除', (tester) async {
    final records = <DailyRecord>[
      for (var day = 10; day <= 12; day++)
        DailyRecord(
          date: nov(day),
          hasPeriod: true,
          bleedingLevel: BleedingLevel.medium,
        ),
    ];
    final result = await openSheet(
      tester,
      records: records,
      editing: PeriodRange(nov(10), nov(12)),
    );

    expect(find.text('調整經期日期'), findsOneWidget);
    expect(find.text('共 3 天'), findsOneWidget);

    await tester.tap(find.text('刪除這次經期'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle();

    final change = result()!;
    expect(change.range, isNull);
    expect(change.delete, <DateTime>[nov(10), nov(11), nov(12)]);
  });
}
