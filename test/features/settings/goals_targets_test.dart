import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/dashboard/domain/card_catalog.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/settings/presentation/goals_screen.dart';
import 'package:fitpath/features/settings/presentation/targets_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<AppDatabase> _db(
  WidgetTester tester, [
  Future<void> Function(ProfileRepository p, DashboardRepository d)? seed,
]) async {
  final db = createTestDatabase();
  await tester.runAsync(() async {
    await db.customSelect('SELECT 1').get();
    await seed?.call(
      ProfileRepository(db.profileDao),
      DashboardRepository(db.dashboardDao),
    );
  });
  return db;
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Widget screen) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/s',
    routes: [GoRoute(path: '/s', builder: (_, _) => screen)],
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

Future<List<DashboardCardType>> _layout(WidgetTester tester, AppDatabase db) =>
    tester
        .runAsync(
          () => DashboardRepository(db.dashboardDao).watchLayout().first,
        )
        .then((cards) => [for (final c in cards!) c.cardType]);

Future<void> _seedGoal(ProfileRepository p, DashboardRepository d) async {
  await p.setPrimaryGoal(GoalType.loseWeight, targetWeightKg: 70);
  await d.applyPreset(GoalType.loseWeight);
  await d.addCard(DashboardCardType.strengthProgression); // customised
}

void main() {
  group('goals', () {
    testWidgets('changing the main goal keeps history and the layout', (
      tester,
    ) async {
      final db = await _db(tester, _seedGoal);
      final before = await _layout(tester, db);
      await _pump(tester, db, const GoalsSettingsScreen());

      expect(
        find.widgetWithText(TextField, 'Target weight (optional)'),
        findsOne,
      );
      await tester.tap(find.text('Build muscle').first); // main goal list
      await tester.pump();
      await tester.tap(find.text('General fitness').last); // secondary chip
      await tester.pump();
      await tester.tap(find.text('SAVE'));
      await _settle(tester);

      expect(find.text('Update your Home dashboard?'), findsOneWidget);
      await tester.tap(find.text('Keep current'));
      await _settle(tester);

      expect(await _layout(tester, db), before);
      final all = (await tester.runAsync(
        () => db.select(db.fitnessGoals).get(),
      ))!;
      final lose = all.singleWhere((g) => g.goalType == GoalType.loseWeight);
      expect(lose.isActive, isFalse); // kept as history, not deleted
      final active = all.where((g) => g.isActive).toList();
      expect(
        active.singleWhere((g) => g.isPrimary).goalType,
        GoalType.buildMuscle,
      );
      expect(
        active.singleWhere((g) => !g.isPrimary).goalType,
        GoalType.generalFitness,
      );
      await _dispose(tester, db);
    });

    testWidgets('the new preset is applied only when chosen', (tester) async {
      final db = await _db(tester, _seedGoal);
      await _pump(tester, db, const GoalsSettingsScreen());
      await tester.tap(find.text('Improve strength').first);
      await tester.pump();
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      await tester.tap(find.text('USE NEW LAYOUT'));
      await _settle(tester);

      expect(await _layout(tester, db), [
        for (final c in GoalPresets.forGoal(GoalType.improveStrength)) c.type,
      ]);
      await _dispose(tester, db);
    });

    testWidgets('saving without a type change does not ask', (tester) async {
      final db = await _db(tester, _seedGoal);
      await _pump(tester, db, const GoalsSettingsScreen());
      await tester.tap(find.text('SAVE'));
      await _settle(tester);
      expect(find.text('Update your Home dashboard?'), findsNothing);
      await _dispose(tester, db);
    });
  });

  group('targets', () {
    testWidgets('manual targets start today; past days keep old ones', (
      tester,
    ) async {
      final today = Dates.startOfDay(DateTime.now());
      final db = await _db(
        tester,
        (p, _) => p.setTargets(
          calories: 2100,
          proteinG: 140,
          source: TargetSource.calculated,
          effectiveFrom: Dates.addDays(today, -10),
        ),
      );
      await _pump(tester, db, const TargetsScreen());
      expect(find.text('2,100 kcal · P 140'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Calories'),
        '1900',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Protein'), '150');
      await tester.pump();
      await tester.tap(find.text('SAVE TARGETS'));
      await _settle(tester);

      final profile = ProfileRepository(db.profileDao);
      final now = (await tester.runAsync(() => profile.targetsOn(today)))!;
      expect(now.calories, 1900);
      expect(now.proteinG, 150);
      expect(now.source, TargetSource.user);
      final past = (await tester.runAsync(
        () => profile.targetsOn(Dates.addDays(today, -1)),
      ))!;
      expect(past.calories, 2100);
      await _dispose(tester, db);
    });

    testWidgets('suggested targets need details, then can be used', (
      tester,
    ) async {
      final db = await _db(tester);
      await _pump(tester, db, const TargetsScreen());
      expect(find.text('COMPLETE YOUR DETAILS'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'SAVE TARGETS'),
            )
            .onPressed,
        isNull,
      );
      await _dispose(tester, db);

      final db2 = await _db(tester, (p, _) async {
        await p.saveProfile(
          ageYears: 30,
          heightCm: 175,
          sex: Sex.female,
          activityLevel: ActivityLevel.light,
        );
        await p.logWeight(68);
        await p.setPrimaryGoal(GoalType.maintainWeight);
      });
      await _pump(tester, db2, const TargetsScreen());
      await tester.tap(find.text('USE SUGGESTED TARGETS'));
      await _settle(tester);
      final t = (await tester.runAsync(
        () => ProfileRepository(db2.profileDao).targetsOn(DateTime.now()),
      ))!;
      expect(t.source, TargetSource.calculated);
      expect(t.calories, greaterThan(1000));
      await _dispose(tester, db2);
    });
  });
}
