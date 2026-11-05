import 'dart:async';

import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/router/app_router.dart';
import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/onboarding/application/onboarding_status_provider.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:fitpath/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_database.dart';

class _Harness {
  _Harness(this.container) : router = container.read(appRouterProvider);

  final ProviderContainer container;
  final GoRouter router;

  Widget get app => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<_Harness> _pump(
  WidgetTester tester, {
  bool onboardingDone = true,
}) async {
  final db = createTestDatabase();
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      onboardingCompletedProvider.overrideWithValue(onboardingDone),
      appDatabaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(container.dispose);
  final h = _Harness(container);
  await tester.pumpWidget(h.app);
  await tester.pumpAndSettle();
  return h;
}

/// A screen's title, whether it uses an [AppBar] or a [ScreenHeader].
Finder _title(String title) => find.byWidgetPredicate(
  (w) =>
      (w is AppBar && w.title is Text && (w.title! as Text).data == title) ||
      (w is ScreenHeader && w.title == title),
);

void main() {
  testWidgets('every tab is reachable from the bottom navigation', (
    tester,
  ) async {
    await _pump(tester);
    expect(_title('Today'), findsOneWidget);

    for (final (label, title) in [
      ('Nutrition', 'Nutrition'),
      ('Workouts', 'Workouts'),
      ('Progress', 'Progress'),
      ('Profile', 'Profile'),
      ('Home', 'Today'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(_title(title), findsOneWidget, reason: label);
    }
  });

  testWidgets('every route resolves to its screen', (tester) async {
    final h = await _pump(tester);
    final day = DateTime(2026, 11, 3);

    final routes = <String, String>{
      Routes.home: 'Today',
      Routes.nutrition: 'Nutrition',
      Routes.nutritionDay(day): 'Nutrition',
      Routes.foodSearch(meal: MealType.lunch, date: day): 'Search foods',
      Routes.foodDetails(12): 'Food details',
      Routes.newEntry(foodId: 12, meal: MealType.snack): 'Log food',
      Routes.editEntry(5): 'Edit entry',
      Routes.newCustomFood: 'Custom food',
      Routes.editCustomFood(12): 'Custom food',
      Routes.workouts: 'Workouts',
      Routes.activeSession: 'Workout',
      Routes.exercisePicker: 'Add exercise',
      Routes.newCustomExercise: 'Custom exercise',
      Routes.editCustomExercise(3): 'Custom exercise',
      Routes.sessionDetail(7): 'Session',
      Routes.progress: 'Progress',
      Routes.profile: 'Profile',
      Routes.profileDetails: 'Your details',
      Routes.goals: 'Goals',
      Routes.targets: 'Nutrition targets',
      Routes.backup: 'Backup & restore',
      Routes.reset: 'Reset data',
      Routes.about: 'About',
    };

    for (final MapEntry(key: location, value: title) in routes.entries) {
      h.router.go(location);
      await tester.pumpAndSettle();
      expect(_title(title), findsOneWidget, reason: location);
    }
  });

  testWidgets('unknown locations and bad ids show "not found"', (tester) async {
    final h = await _pump(tester);

    for (final location in ['/nope', '/nutrition/food/abc']) {
      h.router.go(location);
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget, reason: location);
    }
  });

  testWidgets('detail screens stay inside their tab and back returns', (
    tester,
  ) async {
    final h = await _pump(tester);

    h.router.go(Routes.nutrition);
    await tester.pumpAndSettle();
    unawaited(h.router.push(Routes.foodDetails(1)));
    await tester.pumpAndSettle();
    expect(_title('Food details'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_title('Nutrition'), findsOneWidget);
  });

  testWidgets('each tab keeps its own stack', (tester) async {
    final h = await _pump(tester);

    h.router.go(Routes.nutrition);
    await tester.pumpAndSettle();
    unawaited(h.router.push(Routes.foodDetails(1)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nutrition').last);
    await tester.pumpAndSettle();

    expect(_title('Food details'), findsOneWidget);
  });

  testWidgets('first launch redirects to onboarding', (tester) async {
    final h = await _pump(tester, onboardingDone: false);
    expect(find.text('GET STARTED'), findsOneWidget); // the welcome screen
    expect(find.byType(NavigationBar), findsNothing);

    h.router.go(Routes.nutrition);
    await tester.pumpAndSettle();
    expect(find.text('GET STARTED'), findsOneWidget); // the welcome screen

    h.router.go(Routes.setup);
    await tester.pumpAndSettle();
    expect(_title("Let's get you set up"), findsOneWidget);
  });

  testWidgets('after onboarding, onboarding routes go to Home', (tester) async {
    final h = await _pump(tester);

    h.router.go(Routes.welcome);
    await tester.pumpAndSettle();
    expect(_title('Today'), findsOneWidget);
  });

  test('route builders encode parameters', () {
    final day = DateTime(2026, 11, 3);
    expect(Routes.nutritionDay(day), '/nutrition?date=2026-11-03');
    expect(
      Routes.newEntry(foodId: 4, meal: MealType.dinner, date: day),
      '/nutrition/entry/new?foodId=4&meal=dinner&date=2026-11-03',
    );
    expect(Routes.foodSearch(), '/nutrition/search');
  });
}
