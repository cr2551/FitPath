import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';
import '../app_database.dart';
import '../tables/app_tables.dart';

part 'dashboard_dao.g.dart';

/// Dashboard layout queries: one row per card.
@DriftAccessor(tables: [DashboardCards])
class DashboardDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.attachedDatabase);

  /// All cards (visible and hidden) in display order.
  Stream<List<DashboardCard>> watchLayout() =>
      (select(dashboardCards)..orderBy([
            (c) => OrderingTerm.asc(c.position),
            (c) => OrderingTerm.asc(c.id),
          ]))
          .watch();

  Future<List<DashboardCard>> layout() =>
      (select(dashboardCards)..orderBy([
            (c) => OrderingTerm.asc(c.position),
            (c) => OrderingTerm.asc(c.id),
          ]))
          .get();

  /// Replaces the whole layout in one transaction.
  Future<void> replaceLayout(List<DashboardCardsCompanion> cards) =>
      transaction(() async {
        await delete(dashboardCards).go();
        await batch((b) => b.insertAll(dashboardCards, cards));
      });

  /// Rewrites positions so [idsInOrder] come first, in that order.
  Future<void> reorder(List<int> idsInOrder) => transaction(() async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(dashboardCards)..where((c) => c.id.equals(idsInOrder[i])))
          .write(DashboardCardsCompanion(position: Value(i)));
    }
  });

  Future<void> setVisible(int id, bool visible) =>
      (update(dashboardCards)..where((c) => c.id.equals(id))).write(
        DashboardCardsCompanion(isVisible: Value(visible)),
      );

  Future<DashboardCard?> cardOfType(DashboardCardType type) => (select(
    dashboardCards,
  )..where((c) => c.cardType.equalsValue(type))).getSingleOrNull();

  Future<int> insertCard(DashboardCardsCompanion card) =>
      into(dashboardCards).insert(card);

  Future<int> nextPosition() async {
    final max = dashboardCards.position.max();
    final row = await (selectOnly(
      dashboardCards,
    )..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<void> removeCard(int id) =>
      (delete(dashboardCards)..where((c) => c.id.equals(id))).go();
}
