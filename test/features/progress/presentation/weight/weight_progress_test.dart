import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/progress/presentation/weight/weight_progress_view.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_database.dart';

WeightEntry _w(int id, double kg, DateTime at, [String? notes]) =>
    WeightEntry(id: id, weightKg: kg, recordedAt: at, notes: notes);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ListView(children: const [WeightProgressView()])),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

void main() {
  group('mapping', () {
    final entries = [
      _w(3, 74.2, DateTime(2026, 11, 3, 7, 12)),
      _w(2, 74.4, DateTime(2026, 10, 31, 7, 40), 'after run'),
      _w(1, 75.5, DateTime(2026, 10, 5, 8)),
    ];

    test('current, change, stats and rows', () {
      final d = weightProgressData(
        entries,
        RangePreset.days30,
        UnitSystem.metric,
        72,
      );
      expect(d.current, '74.2');
      expect(d.change, '1.3 kg');
      expect(d.changeDown, isTrue);
      expect(d.changeTowardGoal, isTrue);
      expect(d.points.map((p) => p.value), [75.5, 74.4, 74.2]);
      expect(d.target, 72);
      expect(d.targetLabel, 'Target 72.0 kg');
      expect(d.stats.map((s) => s.value), ['75.5', '74.2', '74.7']);
      expect(d.rows.first.date, 'Tue 3 Nov');
      expect(d.rows[1].detail, '07:40 · after run');
    });

    test('imperial and no target', () {
      final d = weightProgressData(
        entries,
        RangePreset.days30,
        UnitSystem.imperial,
        null,
      );
      expect(d.current, '163.6');
      expect(d.unit, 'lb');
      expect(d.target, isNull);
      expect(d.changeTowardGoal, isFalse);
    });

    test('empty range', () {
      final d = weightProgressData(
        const [],
        RangePreset.days7,
        UnitSystem.metric,
        null,
      );
      expect(d.points, isEmpty);
      expect(d.current, isNull);
    });
  });

  testWidgets('log, edit and delete entries', (tester) async {
    final db = createTestDatabase();
    await _pump(tester, db);
    expect(find.text('No weight entries in this range.'), findsOneWidget);

    await tester.tap(find.text('Log weight').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '74.2');
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes (optional)'),
      'morning',
    );
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('1 in range'), findsOneWidget);
    expect(find.textContaining('morning'), findsOneWidget);

    // A second, older entry gives a change.
    await tester.runAsync(
      () =>
          ProfileRepository(db.profileDao)
              .logWeight(75.5, at: Dates.addDays(DateTime.now(), -10)),
    );
    await _settle(tester);
    expect(find.text(' 1.3 kg'), findsOneWidget);
    expect(find.byIcon(Icons.south), findsOneWidget);
    expect(find.text('Measured'), findsOneWidget);

    // Edit the newest entry.
    await tester.tap(find.textContaining('morning'));
    await tester.pumpAndSettle();
    expect(find.text('Edit weight'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Weight'), '74.0');
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await _settle(tester);
    var rows = await tester.runAsync(() => db.select(db.weightEntries).get());
    expect(rows!.map((r) => r.weightKg), containsAll([74.0, 75.5]));

    // Delete it.
    await tester.tap(find.textContaining('morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await _settle(tester);
    rows = await tester.runAsync(() => db.select(db.weightEntries).get());
    expect(rows!.single.weightKg, 75.5);
    await _dispose(tester, db);
  });
}
