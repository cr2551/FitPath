import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/dashboard_dao.dart';
import '../../../shared/models/enums.dart';
import '../domain/card_catalog.dart';

/// The user's Home layout. Changes persist immediately (FR-12).
///
/// The layout is independent of the goal: changing the goal never applies a
/// preset by itself. Callers ask the user first, then call [applyPreset].
class DashboardRepository {
  DashboardRepository(this._dao);

  final DashboardDao _dao;

  /// Every card, visible or hidden, in display order.
  Stream<List<DashboardCard>> watchLayout() => _dao.watchLayout();

  /// Replaces the layout with the preset for [goal].
  Future<void> applyPreset(GoalType goal) {
    final preset = GoalPresets.forGoal(goal);
    return _dao.replaceLayout([
      for (var i = 0; i < preset.length; i++)
        DashboardCardsCompanion.insert(
          cardType: preset[i].type,
          position: i,
          cardSize: Value(CardCatalog.of(preset[i].type).defaultSize),
          configJson: Value(preset[i].config),
        ),
    ]);
  }

  /// Adds a card at the end. Each card type appears at most once: adding a
  /// type that is already on the dashboard just makes it visible again.
  Future<void> addCard(DashboardCardType type) => _dao.transaction(() async {
    final existing = await _dao.cardOfType(type);
    if (existing != null) {
      await _dao.setVisible(existing.id, true);
      return;
    }
    await _dao.insertCard(
      DashboardCardsCompanion.insert(
        cardType: type,
        position: await _dao.nextPosition(),
        cardSize: Value(CardCatalog.of(type).defaultSize),
      ),
    );
  });

  /// Card types not yet on the dashboard, for the "Add cards" library.
  Future<List<CardDefinition>> availableToAdd() async {
    final present = {for (final c in await _dao.layout()) c.cardType};
    return [
      for (final d in CardCatalog.all)
        if (!present.contains(d.type)) d,
    ];
  }

  Future<void> reorder(List<int> cardIdsInOrder) =>
      _dao.reorder(cardIdsInOrder);

  Future<void> setVisible(int cardId, bool visible) =>
      _dao.setVisible(cardId, visible);

  Future<void> removeCard(int cardId) => _dao.removeCard(cardId);
}
