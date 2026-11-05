import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/dashboard/presentation/cards/nutrition_summary_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/weight_trend_card.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

WeightEntry _w(int id, double kg, DateTime at) =>
    WeightEntry(id: id, weightKg: kg, recordedAt: at);

NutrientTotals _day(double kcal) => NutrientTotals(
  kcal: kcal,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
  entryCount: 1,
  entriesMissingKcal: 0,
  entriesMissingMacros: 0,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Widget card) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: ListView(children: [card])),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
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
  group('weight trend mapping', () {
    final entries = [
      _w(3, 74.2, DateTime(2026, 11, 3)),
      _w(2, 74.8, DateTime(2026, 10, 20)),
      _w(1, 75.5, DateTime(2026, 10, 5)),
    ];

    test('latest value, change over the period and sparkline', () {
      final d = weightTrendViewData(
        entries: entries,
        latestKg: 74.2,
        units: UnitSystem.metric,
        targetKg: 72,
      );
      expect(d.value, '74.2');
      expect(d.unit, 'kg');
      expect(d.change!.label, '1.3 kg · last 30 days');
      expect(d.change!.down, isTrue);
      expect(d.change!.towardGoal, isTrue);
      expect(d.points, [75.5, 74.8, 74.2]);
    });

    test('moving away from the target is not shown as success', () {
      final d = weightTrendViewData(
        entries: entries,
        latestKg: 74.2,
        units: UnitSystem.metric,
        targetKg: 80,
      );
      expect(d.change!.towardGoal, isFalse);
    });

    test('imperial units', () {
      final d = weightTrendViewData(
        entries: entries,
        latestKg: 74.2,
        units: UnitSystem.imperial,
        targetKg: null,
      );
      expect(d.value, '163.6');
      expect(d.change!.label, '2.9 lb · last 30 days');
    });

    test('one entry has no change; none is the empty state', () {
      final one = weightTrendViewData(
        entries: [entries.first],
        latestKg: 74.2,
        units: UnitSystem.metric,
        targetKg: null,
      );
      expect(one.change, isNull);
      final none = weightTrendViewData(
        entries: const [],
        latestKg: null,
        units: UnitSystem.metric,
        targetKg: null,
      );
      expect(none.value, isNull);
    });
  });

  group('nutrition summary mapping', () {
    test('averages logged days only', () {
      final d = nutritionSummaryViewData({
        '2026-11-01': _day(1800),
        '2026-11-02': _day(2000),
        '2026-11-03': _day(2200),
      }, 2100);
      expect(d.averageKcal, '2,000');
      expect(d.targetKcal, '2,100');
      expect(d.daysLogged, '3 of 7');
      expect(d.overTarget, isFalse);
    });

    test('over target, no target, nothing logged', () {
      expect(
        nutritionSummaryViewData({'2026-11-01': _day(2500)}, 2100).overTarget,
        isTrue,
      );
      final noTarget = nutritionSummaryViewData({
        '2026-11-01': _day(2500),
      }, null);
      expect(noTarget.targetKcal, '—');
      expect(noTarget.overTarget, isFalse);
      expect(nutritionSummaryViewData({}, 2100).averageKcal, isNull);
    });
  });

  testWidgets('weight card: empty state, log a weight, then the trend', (
    tester,
  ) async {
    final db = createTestDatabase();
    await _pump(tester, db, const WeightTrendCard());
    expect(find.text('No weight logged yet.'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '74.2');
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('Log again to see your trend'), findsOneWidget);
    final saved = await tester.runAsync(
      () => db.select(db.weightEntries).get(),
    );
    expect(saved!.single.weightKg, 74.2);

    await tester.runAsync(
      () => ProfileRepository(db.profileDao).logWeight(
        75.5,
        at: DateTime.now().subtract(const Duration(days: 10)),
      ),
    );
    await _settle(tester);
    expect(find.text('▼ 1.3 kg · last 30 days'), findsOneWidget);

    await tester.tap(find.text('Weight'));
    await tester.pumpAndSettle();
    expect(find.text('route /progress'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('nutrition card: empty state and tap to Nutrition', (
    tester,
  ) async {
    final db = createTestDatabase();
    await _pump(tester, db, const NutritionSummaryCard());
    expect(find.text('Nothing logged in the last 7 days.'), findsOneWidget);
    await tester.tap(find.text('Nutrition summary'));
    await tester.pumpAndSettle();
    expect(find.text('route /nutrition'), findsOneWidget);
    await _dispose(tester, db);
  });
}
