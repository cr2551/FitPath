import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/onboarding/application/onboarding_controller.dart';
import 'package:fitpath/features/onboarding/presentation/estimates_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Sex sex = Sex.male,
  ActivityLevel? activity = ActivityLevel.moderate,
}) async {
  tester.view.physicalSize = const Size(400, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = createTestDatabase();
  final container = ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
  addTearDown(() async {
    container.dispose();
    await tester.runAsync(db.close);
  });
  container.read(onboardingControllerProvider.notifier)
    ..setUnits(UnitSystem.metric)
    ..setAge(30)
    ..setHeightCm(180)
    ..setWeightKg(80)
    ..setSex(sex)
    ..setActivity(activity)
    ..setPrimaryGoal(GoalType.loseWeight);
  final router = GoRouter(
    initialLocation: Routes.estimates,
    routes: [
      GoRoute(
        path: Routes.estimates,
        builder: (_, _) => const EstimatesScreen(),
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

FilledButton _finish(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'FINISH SETUP'),
);

void main() {
  testWidgets('shows estimates and pre-fills the suggested targets', (
    tester,
  ) async {
    final container = await _pump(tester);
    // Mifflin-St Jeor: 10 x 80 + 6.25 x 180 - 5 x 30 + 5 = 1,780.
    expect(find.text('1,780 kcal'), findsOneWidget);
    expect(find.text('24.7'), findsOneWidget); // BMI
    expect(find.text('Suggested for your goal'), findsOneWidget);

    final t = container.read(onboardingControllerProvider).targets!;
    final suggested = suggestedTargets(
      container.read(onboardingControllerProvider),
    )!;
    expect(t.calories, suggested.calories);
    expect(t.editedByUser, isFalse);
    expect(find.text('${t.calories}'), findsOneWidget);
    expect(_finish(tester).onPressed, isNotNull);

    await tester.tap(find.text('ESTIMATE'));
    await tester.pumpAndSettle();
    expect(find.text('How these are calculated'), findsOneWidget);
  });

  testWidgets('editing marks the targets as set by the user', (tester) async {
    final container = await _pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Calories'), '2000');
    await tester.enterText(find.widgetWithText(TextField, 'Protein'), '');
    await tester.pump();

    var t = container.read(onboardingControllerProvider).targets!;
    expect(t.calories, 2000);
    expect(t.proteinG, isNull);
    expect(t.editedByUser, isTrue);
    expect(find.text('Set by you'), findsOneWidget);

    // Invalid calories block finishing.
    await tester.enterText(find.widgetWithText(TextField, 'Calories'), '100');
    await tester.pump();
    expect(_finish(tester).onPressed, isNull);

    await tester.tap(find.text('Use suggestion'));
    await tester.pumpAndSettle();
    t = container.read(onboardingControllerProvider).targets!;
    expect(t.editedByUser, isFalse);
    expect(t.proteinG, isNotNull);
    expect(_finish(tester).onPressed, isNotNull);

    await tester.tap(find.text('FINISH SETUP'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('route ${Routes.home}'), findsOneWidget);
    // Completing onboarding saved the edited targets.
    final db = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(appDatabaseProvider);
    final saved = await tester.runAsync(
      () => db.select(db.nutritionTargets).get(),
    );
    expect(saved!.single.source, TargetSource.calculated);
  });

  testWidgets('explains skipped sex and missing inputs', (tester) async {
    await _pump(tester, sex: Sex.unspecified, activity: null);
    expect(find.textContaining('Missing activity level'), findsOneWidget);
    expect(find.textContaining('Sex was not provided'), findsOneWidget);
    expect(_finish(tester).onPressed, isNull);
  });
}
