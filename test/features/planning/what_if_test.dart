import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/planning/presentation/projection_chart.dart';
import 'package:fitpath/features/planning/presentation/what_if_screen.dart';
import 'package:fitpath/features/planning/presentation/what_if_view.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/profile/domain/metabolic_profile.dart';
import 'package:fitpath/features/profile/domain/weight_projection.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/test_database.dart';

void main() {
  final today = DateTime(2026, 11, 16);
  const profile = MetabolicProfile(
    ageYears: 30,
    heightCm: 180,
    weightKg: 90,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    goal: GoalType.loseWeight,
  );

  test('the chart and date match the projection for a fixed profile', () {
    final d = whatIfViewData(
      profile: profile,
      kcal: 2200,
      activity: ActivityLevel.moderate,
      targetKg: 85,
      weights: [
        WeightEntry(id: 1, weightKg: 91, recordedAt: DateTime(2026, 11, 1)),
      ],
      today: today,
      units: UnitSystem.metric,
    );
    final expected = WeightProjectionCalculator.project(
      profile: profile,
      intakeKcal: 2200,
      start: today,
      targetWeightKg: 85,
    ).value!;

    final r = d.result!;
    expect(d.missingDetails, isNull);
    expect(r.projected.first.value, 90);
    expect(r.projected.first.at, today);
    expect(r.projected.last.value, expected.finalWeightKg);
    expect(r.projected.last.at, expected.targetReachedOn);
    expect(
      r.estimatedDate,
      DateFormat('d MMM y').format(expected.targetReachedOn!),
    );
    expect(r.measured.single.value, 91);
    expect(r.target, 85);
    expect(r.weeklyPace, startsWith('−'));
    expect(r.warnings, isEmpty);
    expect(d.canApply, isTrue);
  });

  test('guardrail warnings and imperial units', () {
    final d = whatIfViewData(
      profile: profile,
      kcal: 1200,
      activity: ActivityLevel.moderate,
      targetKg: null,
      weights: const [],
      today: today,
      units: UnitSystem.imperial,
    );
    final r = d.result!;
    expect(r.warnings, [
      WeightProjectionCalculator.fastPaceNote,
      WeightProjectionCalculator.belowFloorNote,
    ]);
    expect(r.estimatedDate, 'No target set');
    expect(r.weeklyPace, endsWith('lb a week'));
    expect(r.projected.first.value, closeTo(198.4, 0.1));
  });

  test('missing profile details are named and nothing is projected', () {
    final d = whatIfViewData(
      profile: const MetabolicProfile(weightKg: 80),
      kcal: 2000,
      activity: ActivityLevel.light,
      targetKg: null,
      weights: const [],
      today: today,
      units: UnitSystem.metric,
    );
    expect(d.result, isNull);
    expect(
      d.missingDetails,
      'Add your age and height in Your details to see a projection.',
    );
    // Applying the intake does not need a projection.
    expect(d.canApply, isTrue);
  });

  testWidgets('the projection card renders with its warnings', (tester) async {
    final data = whatIfViewData(
      profile: profile,
      kcal: 1200,
      activity: ActivityLevel.moderate,
      targetKg: 85,
      weights: [
        WeightEntry(id: 1, weightKg: 91, recordedAt: DateTime(2026, 11, 1)),
      ],
      today: today,
      units: UnitSystem.metric,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WhatIfView(
          data: data,
          callbacks: WhatIfCallbacks(
            onKcal: (_) {},
            onActivity: (_) {},
            onTarget: (_) {},
            onApply: () {},
            onEditDetails: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text(WeightProjectionCalculator.belowFloorNote),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byType(ProjectionChart), findsOneWidget);
    expect(find.text(WeightProjectionCalculator.fastPaceNote), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applying adds a target effective today; yesterday keeps its', (
    tester,
  ) async {
    final db = createTestDatabase();
    final repo = ProfileRepository(db.profileDao);
    final now = DateTime.now();
    final yesterday = Dates.addDays(now, -1);
    await tester.runAsync(
      () => repo.setTargets(
        calories: 2200,
        source: TargetSource.user,
        effectiveFrom: yesterday,
      ),
    );

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const WhatIfScreen()),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Prefilled from the current targets; no profile details yet.
    expect(find.text('2200'), findsOneWidget);
    expect(find.text('COMPLETE YOUR DETAILS'), findsOneWidget);

    await tester.enterText(find.text('2200'), '1900');
    await tester.pump();
    await tester.ensureVisible(find.text('APPLY AS MY TARGETS'));
    await tester.tap(find.text('APPLY AS MY TARGETS'));
    await tester.pumpAndSettle();
    expect(find.text('Apply 1,900 kcal a day?'), findsOneWidget);
    await tester.tap(find.text('APPLY'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    final (todays, yesterdays) = await tester.runAsync(
      () async => (await repo.targetsOn(now), await repo.targetsOn(yesterday)),
    ) as (NutritionTarget?, NutritionTarget?);
    expect(todays!.calories, 1900);
    expect(todays.source, TargetSource.user);
    expect(todays.effectiveFrom, Dates.localDateKey(now));
    expect(yesterdays!.calories, 2200);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
