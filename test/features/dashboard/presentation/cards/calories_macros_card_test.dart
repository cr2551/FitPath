import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/theme/fit_colors.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/dashboard/presentation/cards/calories_macros_card.dart';
import 'package:fitpath/features/dashboard/presentation/cards/calories_macros_card_view.dart';
import 'package:fitpath/features/dashboard/presentation/cards/calories_macros_view_data.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

final _today = DateTime(2026, 11, 3); // a Tuesday

NutritionTarget _target({
  int calories = 2100,
  double? proteinG = 140,
  double? carbsG = 230,
  double? fatG = 70,
}) => NutritionTarget(
  id: 1,
  calories: calories,
  proteinG: proteinG,
  carbsG: carbsG,
  fatG: fatG,
  effectiveFrom: '2026-11-01',
  source: TargetSource.user,
  createdAt: DateTime(2026, 11, 1),
);

DailyNutritionSummary _day(List<Nutrients> items) => DailyNutritionSummary([
  for (final n in items) LoggedNutrients(meal: MealType.lunch, nutrients: n),
]);

/// The design example: 1,640 kcal from 110 g protein, 180 g carbs, 53 g fat.
const _example = Nutrients(kcal: 1640, proteinG: 110, carbsG: 180, fatG: 53);

CaloriesMacrosViewData _map(
  List<Nutrients> items, {
  NutritionTarget? target,
  bool noTarget = false,
  DateTime? day,
  int workouts = 2,
}) => caloriesMacrosViewData(
  summary: _day(items),
  target: noTarget ? null : (target ?? _target()),
  day: day ?? _today,
  today: _today,
  workoutsInWeek: workouts,
);

void main() {
  group('view data mapping', () {
    test('on track: segments use 4/4/9 kcal per gram', () {
      final d = _map([_example]);
      expect(d.segments.protein, 440);
      expect(d.segments.carbs, 720);
      expect(d.segments.fat, 477);
      expect(d.segments.unknown, 0);
      expect(d.title, 'Calorie goal: 2,100 kcal');
      expect(d.status.number, '460');
      expect(d.status.text, 'kcal remaining today');
      expect(d.status.over, isFalse);
      expect(d.eatenLabel, '1,640');
      expect(d.goalKcal, 2100);
      expect(
        [for (final m in d.macros) (m.share! * 100).round()],
        [27, 44, 29],
      );
      expect(d.unknown, isNull);
      expect(
        d.semanticsLabel,
        '1,640 of 2,100 calories eaten, 460 left. '
        'Protein 27 percent, carbs 44 percent, fat 29 percent.',
      );
      expect(d.workoutsLabel, '2 workouts this week');
    });

    test('over target never shows a negative remaining', () {
      final d = _map([
        const Nutrients(kcal: 2220, proteinG: 150, carbsG: 250, fatG: 70),
      ]);
      expect(d.status.number, '120');
      expect(d.status.text, 'kcal over today');
      expect(d.status.over, isTrue);
      expect(
        d.semanticsLabel,
        startsWith('2,220 of 2,100 calories eaten, 120 over.'),
      );
    });

    test('nothing logged', () {
      final d = _map([], workouts: 0);
      expect(d.status.number, isNull);
      expect(d.status.text, 'Log your first meal');
      expect(d.eatenLabel, '0');
      expect(d.macros.every((m) => m.share == null), isTrue);
      expect(d.mealsLabel, 'No meals');
      expect(d.workoutsLabel, 'No workouts this week');
    });

    test('calories without a macro split become the unknown segment', () {
      final d = _map([_example, const Nutrients(kcal: 210)]);
      expect(d.segments.unknown, 210);
      expect(d.eatenKcal, 1850);
      expect(d.unknown!.kcalLabel, '210 kcal');
      expect(d.unknown!.share, closeTo(210 / 1847, 1e-9));
      expect(d.semanticsLabel, contains('unknown 11 percent'));
    });

    test('no calorie goal', () {
      final d = _map([_example], noTarget: true);
      expect(d.title, 'Set a calorie goal');
      expect(d.goalKcal, isNull);
      expect(d.status.number, '1,640');
      expect(d.status.text, 'kcal eaten today');
      expect(d.macros.every((m) => m.targetG == null), isTrue);
      expect(
        d.semanticsLabel,
        startsWith('1,640 calories eaten, no calorie goal.'),
      );
    });

    test('unset macro target stays null', () {
      final d = _map([_example], target: _target(fatG: null));
      expect(d.macros.last.targetG, isNull);
      expect(d.macros.first.targetG, 140);
    });

    test('historical date names the day and its week', () {
      final d = _map([_example], day: DateTime(2026, 10, 26));
      expect(d.status.text, 'kcal remaining on Mon 26 Oct');
      expect(d.workoutsLabel, '2 workouts that week');
      expect(
        _map([], day: DateTime(2026, 10, 26)).status.text,
        'Nothing logged on Mon 26 Oct',
      );
    });

    test('meal count counts meals with entries', () {
      final d = caloriesMacrosViewData(
        summary: DailyNutritionSummary(const [
          LoggedNutrients(meal: MealType.breakfast, nutrients: _example),
          LoggedNutrients(meal: MealType.breakfast, nutrients: _example),
          LoggedNutrients(meal: MealType.dinner, nutrients: _example),
        ]),
        target: _target(),
        day: _today,
        today: _today,
        workoutsInWeek: 1,
      );
      expect(d.mealsLabel, '2 meals');
      expect(d.workoutsLabel, '1 workout this week');
    });
  });

  group('view', () {
    Future<void> pumpView(
      WidgetTester tester,
      CaloriesMacrosViewData data, {
      VoidCallback? onTap,
      VoidCallback? onSetGoal,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CaloriesMacrosCardView(
                data: data,
                onTap: onTap ?? () {},
                onSetGoal: onSetGoal,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('on track', (tester) async {
      final semantics = tester.ensureSemantics();
      var tapped = false;
      await pumpView(tester, _map([_example]), onTap: () => tapped = true);
      expect(find.text('Calorie goal: 2,100 kcal'), findsOneWidget);
      expect(find.textContaining('460'), findsWidgets);
      expect(find.text('1,640'), findsOneWidget);
      expect(find.text('EATEN'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('27%'), findsOneWidget);
      expect(find.text('1 meal'), findsOneWidget);
      expect(find.text('2 workouts this week'), findsOneWidget);
      expect(find.text('Set goal'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'^1,640 of 2,100 calories eaten')),
        findsOneWidget,
      );
      await tester.tap(find.text('Calorie goal: 2,100 kcal'));
      expect(tapped, isTrue);
      semantics.dispose();
    });

    testWidgets('over target uses the warning color', (tester) async {
      await pumpView(
        tester,
        _map([
          const Nutrients(kcal: 2220, proteinG: 150, carbsG: 250, fatG: 70),
        ]),
      );
      final over = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '120 kcal over today',
        ),
      );
      final ctx = tester.element(find.byType(CaloriesMacrosCardView));
      final span = over.text as TextSpan;
      final children = (span.children!.single as TextSpan).children!;
      expect(children.first.style!.color, ctx.fitColors.warning);
    });

    testWidgets('nothing logged', (tester) async {
      await pumpView(tester, _map([], workouts: 0));
      expect(find.text('Log your first meal'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('No meals'), findsOneWidget);
    });

    testWidgets('unknown macros add a fourth legend row', (tester) async {
      await pumpView(tester, _map([_example, const Nutrients(kcal: 210)]));
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('210 kcal'), findsOneWidget);
    });

    testWidgets('no goal offers to set one', (tester) async {
      var setGoal = false;
      await pumpView(
        tester,
        _map([_example], noTarget: true),
        onSetGoal: () => setGoal = true,
      );
      expect(find.text('Set a calorie goal'), findsOneWidget);
      expect(find.textContaining('Set target'), findsNWidgets(3));
      await tester.tap(find.text('Set goal'));
      expect(setGoal, isTrue);
    });

    testWidgets('unset macro target shows Set target', (tester) async {
      await pumpView(tester, _map([_example], target: _target(fatG: null)));
      expect(find.textContaining('Set target'), findsOneWidget);
    });

    testWidgets('historical date', (tester) async {
      await pumpView(tester, _map([_example], day: DateTime(2026, 10, 26)));
      expect(
        find.textContaining('kcal remaining on Mon 26 Oct'),
        findsOneWidget,
      );
      expect(find.text('2 workouts that week'), findsOneWidget);
    });
  });

  testWidgets('the container reads the selected day, targets and workouts', (
    tester,
  ) async {
    final db = createTestDatabase();
    final now = DateTime.now();
    await tester.runAsync(() async {
      await ProfileRepository(db.profileDao).setTargets(
        calories: 2000,
        proteinG: 150,
        source: TargetSource.user,
        effectiveFrom: Dates.addDays(now, -1),
      );
      final foods = FoodRepository(db.foodDao);
      final id = await foods.createCustomFood(
        const FoodDetails(
          name: 'Oats',
          basis: ReferenceBasis.per100g,
          nutrients: Nutrients(kcal: 400, proteinG: 10, carbsG: 70, fatG: 8),
        ),
      );
      await foods.logFood(
        foodId: id,
        quantity: 100,
        unit: QuantityUnit.gram,
        meal: MealType.breakfast,
      );
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              startedAt: now,
              completedAt: Value(now),
              status: WorkoutStatus.completed,
            ),
          );
    });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: CaloriesMacrosCard()),
          ),
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
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Calorie goal: 2,000 kcal'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('1 meal'), findsOneWidget);
    expect(find.text('1 workout this week'), findsOneWidget);

    await tester.tap(find.text('Calorie goal: 2,000 kcal'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('route /nutrition?date=${Dates.localDateKey(now)}'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
