import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/dashboard/domain/card_catalog.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DashboardRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = DashboardRepository(db.dashboardDao);
  });
  tearDown(() => db.close());

  Future<List<DashboardCardType>> visibleTypes() async => [
    for (final c in await repo.watchLayout().first)
      if (c.isVisible) c.cardType,
  ];

  group('goal presets match the spec table', () {
    final expected = {
      GoalType.loseWeight: [
        DashboardCardType.caloriesMacros,
        DashboardCardType.weightTrend,
        DashboardCardType.nutritionSummary,
        DashboardCardType.workoutSummary,
      ],
      GoalType.buildMuscle: [
        DashboardCardType.caloriesMacros,
        DashboardCardType.workoutSummary,
        DashboardCardType.strengthProgression,
        DashboardCardType.weightTrend,
      ],
      GoalType.maintainWeight: [
        DashboardCardType.caloriesMacros,
        DashboardCardType.weightTrend,
        DashboardCardType.workoutSummary,
      ],
      GoalType.improveStrength: [
        DashboardCardType.workoutSummary,
        DashboardCardType.strengthProgression,
        DashboardCardType.recentSessions,
        DashboardCardType.nutritionSummary,
      ],
      GoalType.generalFitness: [
        DashboardCardType.workoutSummary,
        DashboardCardType.activityOverview,
        DashboardCardType.nutritionSummary,
        DashboardCardType.weightTrend,
      ],
    };

    expected.forEach((goal, types) {
      test(goal.name, () async {
        await repo.applyPreset(goal);
        expect(await visibleTypes(), types);
      });
    });

    test('build muscle emphasises protein on the calories card', () async {
      await repo.applyPreset(GoalType.buildMuscle);
      final first = (await repo.watchLayout().first).first;
      expect(first.configJson, proteinEmphasisConfig);
    });

    test('every card type has a catalog entry', () {
      for (final t in DashboardCardType.values) {
        expect(CardCatalog.of(t).type, t);
      }
    });
  });

  group('editing the layout', () {
    setUp(() => repo.applyPreset(GoalType.loseWeight));

    test('applying another preset replaces the layout', () async {
      await repo.applyPreset(GoalType.maintainWeight);
      expect(await repo.watchLayout().first, hasLength(3));
    });

    test('reorder persists', () async {
      final ids = [for (final c in await repo.watchLayout().first) c.id];
      await repo.reorder(ids.reversed.toList());

      expect(await visibleTypes(), [
        DashboardCardType.workoutSummary,
        DashboardCardType.nutritionSummary,
        DashboardCardType.weightTrend,
        DashboardCardType.caloriesMacros,
      ]);
    });

    test('hide and show', () async {
      final weight = (await repo.watchLayout().first)[1];
      await repo.setVisible(weight.id, false);
      expect(
        await visibleTypes(),
        isNot(contains(DashboardCardType.weightTrend)),
      );
      expect(await repo.watchLayout().first, hasLength(4));

      await repo.setVisible(weight.id, true);
      expect(await visibleTypes(), contains(DashboardCardType.weightTrend));
    });

    test('add appends once; adding a hidden card shows it again', () async {
      await repo.addCard(DashboardCardType.recentSessions);
      await repo.addCard(DashboardCardType.recentSessions);
      expect((await visibleTypes()).last, DashboardCardType.recentSessions);
      expect(await repo.watchLayout().first, hasLength(5));

      final calories = (await repo.watchLayout().first).first;
      await repo.setVisible(calories.id, false);
      await repo.addCard(DashboardCardType.caloriesMacros);
      expect(await visibleTypes(), contains(DashboardCardType.caloriesMacros));
      expect(await repo.watchLayout().first, hasLength(5));
    });

    test('remove, and the library offers what is missing', () async {
      final first = (await repo.watchLayout().first).first;
      await repo.removeCard(first.id);

      final available = [for (final d in await repo.availableToAdd()) d.type];
      expect(available, contains(DashboardCardType.caloriesMacros));
      expect(available, isNot(contains(DashboardCardType.weightTrend)));
    });
  });

  test('an empty dashboard starts at position 0', () async {
    await repo.addCard(DashboardCardType.weightTrend);
    final card = (await repo.watchLayout().first).single;
    expect(card.position, 0);
    expect(card.cardSize, CardSize.compact);
  });
}
