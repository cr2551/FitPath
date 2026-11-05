import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';
import '../../nutrition/application/diary_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../settings/presentation/settings_screen.dart' show goalLabel;
import '../application/dashboard_providers.dart';
import '../application/home_selected_date_provider.dart';
import '../domain/card_catalog.dart';
import 'card_registry.dart';
import 'edit/add_card_sheet.dart';
import 'edit/dashboard_edit_view.dart';
import 'home_view.dart';

/// Local date keys with food entries in the week starting on the keyed day.
final _loggedDaysProvider = StreamProvider.family<Set<String>, String>((
  ref,
  weekStartKey,
) {
  final start = Dates.fromLocalDateKey(weekStartKey);
  return ref
      .watch(foodRepositoryProvider)
      .watchDailyTotals(DateRange(start: start, end: Dates.addDays(start, 7)))
      .map((byDay) => byDay.keys.toSet());
});

/// The Home tab: the user's dashboard cards in their saved order, and edit
/// mode to reorder, hide, remove and add cards. Every change is saved at
/// once (FR-12).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _editing = false;

  @override
  Widget build(BuildContext context) {
    final today = Dates.startOfDay(DateTime.now());
    final selected = ref.watch(homeSelectedDateProvider);
    final week = Dates.weekOf(today);
    final loggedDays = ref.watch(
      _loggedDaysProvider(Dates.localDateKey(week.first)),
    );
    final layout = ref.watch(dashboardLayoutProvider);
    final cards = layout.value ?? const <DashboardCard>[];

    final HomeBody body;
    if (layout.hasError) {
      body = const HomeError("Couldn't load your dashboard.");
    } else if (!layout.hasValue) {
      body = const HomeLoading();
    } else if (_editing) {
      body = HomeEditing([
        for (final c in cards)
          EditCardRowData(
            id: c.id,
            title: CardCatalog.of(c.cardType).title,
            description: CardCatalog.of(c.cardType).description,
            visible: c.isVisible,
          ),
      ]);
    } else {
      body = HomeCards([
        for (final c in cards)
          if (c.isVisible)
            KeyedSubtree(key: ValueKey(c.id), child: CardRegistry.build(c)),
      ]);
    }

    final present = {for (final c in cards) c.cardType};
    final addable = [
      for (final d in CardCatalog.all)
        if (!present.contains(d.type))
          AddCardOption(
            type: d.type,
            title: d.title,
            description: d.description,
          ),
    ];
    final repo = ref.read(dashboardRepositoryProvider);

    return HomeView(
      data: HomeViewData(
        title: Dates.isSameDay(selected, today)
            ? 'Today'
            : DateFormat('EEE d MMM').format(selected),
        goalLine: _goalLine(),
        week: week,
        selected: selected,
        today: today,
        daysWithEntries: loggedDays.value ?? const {},
        body: body,
      ),
      callbacks: HomeCallbacks(
        onProfile: () => context.go(Routes.profile),
        onToggleEdit: () => setState(() => _editing = !_editing),
        onSelectDay: ref.read(homeSelectedDateProvider.notifier).select,
        onLogFood: () => context.go(Routes.foodSearch(date: selected)),
        onStartWorkout: () => context.go(Routes.activeSession),
        onRetry: () => ref.invalidate(dashboardLayoutProvider),
        edit: DashboardEditCallbacks(
          onReorder: (ids) => _save(repo.reorder(ids)),
          onToggleVisible: (id, visible) => _save(repo.setVisible(id, visible)),
          onRemove: (id) => _save(repo.removeCard(id)),
          onAdd: addable.isEmpty ? null : () => _add(addable),
          onRestorePreset: () => _restorePreset(confirm: cards.isNotEmpty),
        ),
      ),
    );
  }

  /// "Lose weight · 72 kg by 1 Mar" from the primary goal.
  String? _goalLine() {
    final goals = ref.watch(activeGoalsProvider).value ?? const [];
    final primary = goals.where((g) => g.isPrimary).firstOrNull;
    if (primary == null) return null;
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final weight = primary.targetWeightKg;
    final date = primary.targetDate;
    final target = [
      if (weight != null) Formatters.weight(weight, units, decimals: 0),
      if (date != null) 'by ${DateFormat('d MMM').format(date)}',
    ].join(' ');
    return [
      goalLabel(primary.goalType),
      if (target.isNotEmpty) target,
    ].join(' · ');
  }

  Future<void> _add(List<AddCardOption> options) async {
    final type = await showAddCardSheet(context, options);
    if (type == null) return;
    await _save(ref.read(dashboardRepositoryProvider).addCard(type));
  }

  Future<void> _restorePreset({required bool confirm}) async {
    if (confirm &&
        !await showConfirmDialog(
          context,
          title: 'Restore the suggested layout?',
          message:
              'Your cards are replaced by the suggested layout for your goal.',
          confirmLabel: 'Restore',
        )) {
      return;
    }
    final goals = ref.read(activeGoalsProvider).value ?? const [];
    final goal =
        goals.where((g) => g.isPrimary).firstOrNull?.goalType ??
        GoalType.generalFitness;
    await _save(ref.read(dashboardRepositoryProvider).applyPreset(goal));
  }

  Future<void> _save(Future<void> change) async {
    try {
      await change;
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your dashboard.")),
      );
    }
  }
}
