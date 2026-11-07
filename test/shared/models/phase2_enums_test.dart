import 'package:drift/drift.dart' hide isNull;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/dashboard/domain/card_catalog.dart';
import 'package:fitpath/features/nutrition/presentation/search/food_labels.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('values are appended, so stored names keep their meaning', () {
    expect(FoodSource.values.map((v) => v.name), [
      'bundled',
      'openFoodFacts',
      'custom',
      'recipe',
    ]);
    expect(DashboardCardType.values.map((v) => v.name).skip(7), [
      'personalRecords',
      'streak',
      'weeklyReport',
    ]);
  });

  test('a recipe food persists and reloads', () async {
    final id = await db.foodDao.insertFood(
      const FoodItemsCompanion(
        name: Value('Chili'),
        referenceBasis: Value(ReferenceBasis.perServing),
        source: Value(FoodSource.recipe),
      ),
    );
    expect((await db.foodDao.foodById(id))!.source, FoodSource.recipe);
    expect(FoodLabels.source(FoodSource.recipe), 'Recipe');
  });

  test('the Phase 2 cards are addable and persist', () async {
    final repo = DashboardRepository(db.dashboardDao);
    final available = [for (final d in await repo.availableToAdd()) d.type];
    const added = [
      DashboardCardType.personalRecords,
      DashboardCardType.streak,
      DashboardCardType.weeklyReport,
    ];
    expect(available, containsAll(added));

    for (final t in added) {
      await repo.addCard(t);
    }
    final layout = await repo.watchLayout().first;
    expect([for (final c in layout) c.cardType], added);
    expect(
      layout[1].cardSize,
      CardCatalog.of(DashboardCardType.streak).defaultSize,
    );
  });

  test('goal presets do not include the Phase 2 cards yet', () {
    for (final goal in GoalType.values) {
      final types = GoalPresets.forGoal(goal).map((c) => c.type);
      expect(types, isNot(contains(DashboardCardType.personalRecords)));
      expect(types, isNot(contains(DashboardCardType.streak)));
      expect(types, isNot(contains(DashboardCardType.weeklyReport)));
    }
  });
}
