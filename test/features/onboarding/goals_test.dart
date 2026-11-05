import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/onboarding/application/onboarding_controller.dart';
import 'package:fitpath/features/onboarding/presentation/goal_details_screen.dart';
import 'package:fitpath/features/onboarding/presentation/goals_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> _pump(WidgetTester tester, String initial) async {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(onboardingControllerProvider.notifier)
    ..setUnits(UnitSystem.metric)
    ..setAge(30)
    ..setHeightCm(180)
    ..setWeightKg(90)
    ..setActivity(ActivityLevel.moderate);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: Routes.onboardingGoals,
        builder: (_, _) => const OnboardingGoalsScreen(),
      ),
      GoRoute(
        path: Routes.goalDetails,
        builder: (_, _) => const GoalDetailsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(body: Text('route ${state.uri}')),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

FilledButton _next(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'NEXT'));

void main() {
  group('weight-loss target check', () {
    final today = DateTime(2026, 11, 4);
    OnboardingDraft draft({double? target, DateTime? date}) => OnboardingDraft(
      units: UnitSystem.metric,
      weightKg: 90,
      primaryGoal: GoalType.loseWeight,
      targetWeightKg: target,
      targetDate: date,
    );

    test('no target, or a reasonable pace, is fine', () {
      expect(goalDetailsProblem(draft(), today), isNull);
      expect(goalDetailsProblem(draft(target: 80), today), isNull);
      // 10 kg in 20 weeks = 0.5 kg/week, under 0.9 kg (1% of 90).
      expect(
        goalDetailsProblem(
          draft(target: 80, date: today.add(const Duration(days: 140))),
          today,
        ),
        isNull,
      );
    });

    test('too fast, wrong direction, or a past date', () {
      // 10 kg in 4 weeks = 2.5 kg/week.
      expect(
        goalDetailsProblem(
          draft(target: 80, date: today.add(const Duration(days: 28))),
          today,
        ),
        contains('1% of your body weight'),
      );
      expect(goalDetailsProblem(draft(target: 95), today), contains('below'));
      expect(
        goalDetailsProblem(draft(target: 80, date: today), today),
        contains('future'),
      );
    });

    test('other goals are not checked', () {
      final d = OnboardingDraft(
        units: UnitSystem.metric,
        weightKg: 90,
        primaryGoal: GoalType.buildMuscle,
        targetWeightKg: 95,
      );
      expect(goalDetailsProblem(d, today), isNull);
    });
  });

  testWidgets('one main goal, secondary goals exclude it', (tester) async {
    final container = await _pump(tester, Routes.onboardingGoals);
    expect(_next(tester).onPressed, isNull);

    await tester.tap(find.text('Build muscle').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Lose weight'));
    await tester.pump();
    expect(find.widgetWithText(FilterChip, 'Build muscle'), findsNothing);
    var d = container.read(onboardingControllerProvider);
    expect(d.primaryGoal, GoalType.buildMuscle);
    expect(d.secondaryGoals, {GoalType.loseWeight});

    // Making the secondary goal the main one removes it from secondary.
    await tester.tap(find.text('Lose weight').first);
    await tester.pump();
    d = container.read(onboardingControllerProvider);
    expect(d.primaryGoal, GoalType.loseWeight);
    expect(d.secondaryGoals, isEmpty);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Configure goals'), findsOneWidget);
  });

  testWidgets('weight loss asks for a target and rejects a fast pace', (
    tester,
  ) async {
    final container = await _pump(tester, Routes.goalDetails);
    final c = container.read(onboardingControllerProvider.notifier)
      ..setPrimaryGoal(GoalType.loseWeight);
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT TARGET (OPTIONAL)'), findsOneWidget);
    expect(find.text('Training experience'), findsNothing);
    expect(_next(tester).onPressed, isNotNull); // target is optional

    await tester.enterText(
      find.widgetWithText(TextField, 'Target weight'),
      '80',
    );
    c.setTargetDate(DateTime.now().add(const Duration(days: 21)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pick a later date'), findsOneWidget);
    expect(_next(tester).onPressed, isNull);
    expect(container.read(onboardingControllerProvider).targetWeightKg, 80);

    await tester.tap(find.text('Clear date'));
    await tester.pumpAndSettle();
    expect(_next(tester).onPressed, isNotNull);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('route ${Routes.estimates}'), findsOneWidget);
  });

  testWidgets('muscle and strength goals ask for experience and days', (
    tester,
  ) async {
    final container = await _pump(tester, Routes.goalDetails);
    container.read(onboardingControllerProvider.notifier)
      ..setPrimaryGoal(GoalType.maintainWeight)
      ..toggleSecondaryGoal(GoalType.improveStrength);
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT TARGET (OPTIONAL)'), findsNothing);
    expect(find.text('Training experience'), findsOneWidget);
    expect(_next(tester).onPressed, isNull);

    await tester.tap(find.text('Training experience'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intermediate (1-3 years)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training days per week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();

    expect(_next(tester).onPressed, isNotNull);
    final d = container.read(onboardingControllerProvider);
    expect(d.experience, TrainingExperience.intermediate);
    expect(d.trainingDaysPerWeek, 3);
  });

  testWidgets('maintain or general fitness: optional days, activity check', (
    tester,
  ) async {
    final container = await _pump(tester, Routes.goalDetails);
    container
        .read(onboardingControllerProvider.notifier)
        .setPrimaryGoal(GoalType.generalFitness);
    await tester.pumpAndSettle();
    expect(
      find.text('Preferred workout days per week (optional)'),
      findsOneWidget,
    );
    expect(find.text('Confirm your activity level'), findsOneWidget);
    expect(_next(tester).onPressed, isNotNull);
  });
}
