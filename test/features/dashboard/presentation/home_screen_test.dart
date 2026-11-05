import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/dashboard/presentation/home_screen.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// A database whose dashboard is the "lose weight" preset:
/// Calories & macros, Weight, Nutrition summary, This week.
Future<AppDatabase> _db(WidgetTester tester, {bool withPreset = true}) async {
  final db = createTestDatabase();
  if (withPreset) {
    await tester.runAsync(
      () =>
          DashboardRepository(db.dashboardDao).applyPreset(GoalType.loseWeight),
    );
  }
  return db;
}

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
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

Future<List<DashboardCard>> _layout(
  WidgetTester tester,
  AppDatabase db,
) async => (await tester.runAsync(() => db.dashboardDao.layout()))!;

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text).first).dy;

void main() {
  testWidgets('shows the saved cards in order with quick actions after the '
      'first card', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Calories & macros'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(
      _top(tester, 'Calories & macros'),
      lessThan(_top(tester, 'LOG FOOD')),
    );
    expect(_top(tester, 'LOG FOOD'), lessThan(_top(tester, 'Weight')));
    expect(_top(tester, 'Weight'), lessThan(_top(tester, 'Nutrition summary')));
    expect(
      _top(tester, 'Nutrition summary'),
      lessThan(_top(tester, 'This week')),
    );

    await _dispose(tester, db);
  });

  testWidgets('hiding and removing cards persists across a restart', (
    tester,
  ) async {
    final db = await _db(tester);
    await _pump(tester, db);

    await tester.tap(find.byTooltip('Edit dashboard'));
    await _settle(tester);
    expect(find.text('Edit dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Weight'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Remove Nutrition summary'));
    await _settle(tester);

    final layout = await _layout(tester, db);
    expect(layout.map((c) => c.cardType), [
      DashboardCardType.caloriesMacros,
      DashboardCardType.weightTrend,
      DashboardCardType.workoutSummary,
    ]);
    expect(layout[1].isVisible, isFalse);

    // A fresh widget tree reads the same layout back.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, db);
    expect(find.text('Calories & macros'), findsOneWidget);
    expect(find.text('Weight'), findsNothing);
    expect(find.text('Nutrition summary'), findsNothing);
    expect(find.text('This week'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('dragging a card reorders and saves the layout', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db);
    await tester.tap(find.byTooltip('Edit dashboard'));
    await _settle(tester);

    // Drag "Calories & macros" below "Weight".
    final handle = find.byIcon(Icons.drag_indicator).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await _settle(tester);

    final layout = await _layout(tester, db);
    expect(layout.first.cardType, DashboardCardType.weightTrend);
    expect(layout[1].cardType, DashboardCardType.caloriesMacros);
    expect(layout[2].cardType, DashboardCardType.nutritionSummary);

    await _dispose(tester, db);
  });

  testWidgets('adds a card from the catalog', (tester) async {
    final db = await _db(tester);
    await _pump(tester, db);
    await tester.tap(find.byTooltip('Edit dashboard'));
    await _settle(tester);

    await tester.tap(find.text('ADD CARDS'));
    await _settle(tester);
    // Only cards not yet on the dashboard are offered.
    expect(find.text('Recent sessions'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget); // the edit row behind
    await tester.tap(find.text('Recent sessions'));
    await _settle(tester);

    final layout = await _layout(tester, db);
    expect(layout.last.cardType, DashboardCardType.recentSessions);
    expect(find.text('Recent sessions'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('an empty dashboard offers the suggested layout', (tester) async {
    final db = await _db(tester, withPreset: false);
    await _pump(tester, db);

    expect(find.text('Your dashboard is empty'), findsOneWidget);
    expect(find.text('LOG FOOD'), findsOneWidget);
    await tester.tap(find.text('Use suggested layout'));
    await _settle(tester);

    // No goal yet: the general fitness preset.
    expect(find.text('Your dashboard is empty'), findsNothing);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Activity overview'), findsOneWidget);

    await _dispose(tester, db);
  });

  testWidgets('the goal line, day selection and quick actions', (tester) async {
    final db = await _db(tester);
    await tester.runAsync(
      () => ProfileRepository(db.profileDao).setPrimaryGoal(
        GoalType.loseWeight,
        targetWeightKg: 72,
        targetDate: DateTime(2027, 3, 1),
      ),
    );
    await _pump(tester, db);
    expect(find.text('Lose weight · 72 kg by 1 Mar'), findsOneWidget);

    final today = Dates.startOfDay(DateTime.now());
    final other = Dates.weekOf(today).firstWhere((d) => d != today);
    await tester.tap(find.text(other.day.toString().padLeft(2, '0')));
    await _settle(tester);
    expect(find.text(DateFormat('EEE d MMM').format(other)), findsOneWidget);
    expect(find.text('Today'), findsNothing);

    await tester.tap(find.text('LOG FOOD'));
    await _settle(tester);
    expect(
      find.textContaining('route /nutrition/search?date='),
      findsOneWidget,
    );

    await _dispose(tester, db);
  });
}
