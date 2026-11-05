import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/onboarding/application/onboarding_controller.dart';
import 'package:fitpath/features/onboarding/presentation/setup_screen.dart';
import 'package:fitpath/features/onboarding/presentation/welcome_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> _pump(WidgetTester tester, String initial) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.setup, builder: (_, _) => const SetupScreen()),
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

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _chooseActivity(WidgetTester tester) async {
  await tester.tap(find.text('Activity level'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Moderate (3-5 days a week)').last);
  await tester.pumpAndSettle();
}

void main() {
  test('units follow the device region', () {
    expect(unitsForLocale(const Locale('en', 'US')), UnitSystem.imperial);
    expect(unitsForLocale(const Locale('en', 'GB')), UnitSystem.metric);
    expect(unitsForLocale(const Locale('es')), UnitSystem.metric);
  });

  testWidgets('welcome leads to setup', (tester) async {
    await _pump(tester, Routes.welcome);
    expect(find.text('FITPATH'), findsOneWidget);
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();
    expect(find.text("Let's get you set up"), findsOneWidget);
  });

  testWidgets('Next stays disabled until the required fields are valid', (
    tester,
  ) async {
    final container = await _pump(tester, Routes.setup);
    await tester.tap(find.text('METRIC (KG, CM)'));
    await tester.pumpAndSettle();
    expect(_next(tester).onPressed, isNull);

    await tester.enterText(_field('Age'), '5');
    await tester.pump();
    expect(find.text('Enter a value between 13 and 100 years'), findsOneWidget);

    await tester.enterText(_field('Age'), '30');
    await tester.enterText(_field('Height'), '180');
    await tester.enterText(_field('Current weight'), '80');
    await tester.pump();
    expect(_next(tester).onPressed, isNull); // activity still missing

    await _chooseActivity(tester);
    expect(_next(tester).onPressed, isNotNull);
    // Sex is optional and defaults to "skip".
    final draft = container.read(onboardingControllerProvider);
    expect(draft.sex, Sex.unspecified);
    expect(draft.ageYears, 30);
    expect(draft.heightCm, 180);
    expect(draft.weightKg, 80);
    expect(draft.activity, ActivityLevel.moderate);

    await tester.enterText(_field('Height'), '');
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(_next(tester).onPressed, isNull);

    await tester.enterText(_field('Height'), '180');
    await tester.pump();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('route ${Routes.onboardingGoals}'), findsOneWidget);
  });

  testWidgets(
    'switching units converts the shown values, not the stored ones',
    (tester) async {
      final container = await _pump(tester, Routes.setup);
      await tester.tap(find.text('METRIC (KG, CM)'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Height'), '180');
      await tester.enterText(_field('Current weight'), '80');
      await tester.pump();

      await tester.tap(find.text('IMPERIAL (LB, IN)'));
      await tester.pumpAndSettle();
      expect(find.text('70.9'), findsOneWidget); // in
      expect(find.text('176.4'), findsOneWidget); // lb
      expect(find.text('in'), findsOneWidget);
      expect(find.text('lb'), findsOneWidget);
      var draft = container.read(onboardingControllerProvider);
      expect(draft.units, UnitSystem.imperial);
      expect(draft.heightCm, 180);
      expect(draft.weightKg, 80);

      // Imperial input is stored in metric.
      await tester.enterText(_field('Current weight'), '200');
      await tester.pump();
      draft = container.read(onboardingControllerProvider);
      expect(draft.weightKg, closeTo(90.718, 0.001));

      // Imperial ranges apply: 20 lb is below 30 kg.
      await tester.enterText(_field('Current weight'), '20');
      await tester.pump();
      expect(
        find.textContaining('Enter a value between 66.1 and 771.6 lb'),
        findsOneWidget,
      );
    },
  );
}
