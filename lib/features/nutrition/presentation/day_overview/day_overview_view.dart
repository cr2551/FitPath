import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import 'day_overview_view_data.dart';

/// Pure layout for the Nutrition tab: plain data and callbacks in.
class DayOverviewView extends StatelessWidget {
  const DayOverviewView({
    super.key,
    required this.data,
    required this.onSelectDay,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onSearch,
    required this.onCreateCustomFood,
    required this.onAddToMeal,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onSetTargets,
    required this.onRetry,
  });

  final DayOverviewViewData data;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onSearch;
  final VoidCallback onCreateCustomFood;
  final ValueChanged<MealType> onAddToMeal;
  final ValueChanged<int> onEditEntry;
  final ValueChanged<int> onDeleteEntry;
  final VoidCallback onSetTargets;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            ScreenHeader(
              title: 'Nutrition',
              trailing: HeaderIconButton(
                icon: Icons.add,
                tooltip: 'Create custom food',
                onPressed: onCreateCustomFood,
              ),
            ),
            _WeekNavigator(
              label: data.weekLabel,
              onPrevious: onPreviousWeek,
              onNext: data.canGoToNextWeek ? onNextWeek : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            DateStrip(
              days: data.week,
              selected: data.selected,
              today: data.today,
              daysWithEntries: data.daysWithEntries,
              onSelected: onSelectDay,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              readOnly: true,
              onTap: onSearch,
              decoration: const InputDecoration(
                hintText: 'Search foods',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...switch (data.body) {
              DayLoading() => const [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              DayError(:final message) => [
                ErrorState(message: message, onRetry: onRetry),
              ],
              DayLoaded(:final summary, :final meals) => [
                _SummaryCard(summary: summary, onSetTargets: onSetTargets),
                for (final meal in meals) ...[
                  const SizedBox(height: AppSpacing.md),
                  _MealCard(
                    group: meal,
                    onAdd: () => onAddToMeal(meal.meal),
                    onEdit: onEditEntry,
                    onDelete: onDeleteEntry,
                  ),
                ],
              ],
            },
          ],
        ),
      ),
    );
  }
}

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.textStyles.bodyStrong,
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onSetTargets});

  final DaySummaryViewData summary;
  final VoidCallback onSetTargets;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final s = summary;
    final goal = s.goalKcal;
    final goalOrZero = goal ?? 0;
    final over = s.hasGoal && s.eatenKcal > goalOrZero;

    final String centerLabel;
    final String semantics;
    if (s.hasGoal) {
      centerLabel = Formatters.percent(s.eatenKcal / goalOrZero);
      semantics =
          '${Formatters.integer(s.eatenKcal)} of ${Formatters.integer(goal)} '
          'calories eaten';
    } else {
      centerLabel = Formatters.integer(s.eatenKcal);
      semantics =
          '${Formatters.integer(s.eatenKcal)} calories eaten, no target set';
    }

    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MacroCalorieRing(
            size: 84,
            strokeWidth: 10,
            gap: 6,
            eatenKcal: s.eatenKcal,
            goalKcal: goal,
            segments: [
              RingSegment(color: c.protein, kcal: s.proteinKcal),
              RingSegment(color: c.carbs, kcal: s.carbsKcal),
              RingSegment(color: c.fat, kcal: s.fatKcal),
              RingSegment(color: c.unknown, kcal: s.unknownKcal),
            ],
            semanticsLabel: semantics,
            center: Text(
              centerLabel,
              style: t.cardTitle.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: Formatters.integer(s.eatenKcal),
                          style: t.cardTitle.copyWith(fontSize: 20),
                          children: [
                            TextSpan(
                              text: s.hasGoal
                                  ? ' / ${Formatters.energy(goal)}'
                                  : ' kcal',
                              style: t.label,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (s.hasGoal)
                      Text.rich(
                        TextSpan(
                          text: Formatters.integer(
                            (s.eatenKcal - goalOrZero).abs(),
                          ),
                          style: t.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: over ? c.warning : c.ink,
                          ),
                          children: [
                            TextSpan(
                              text: over ? ' over' : ' left',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: over ? c.warning : c.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final m in s.macros) _MiniMacroRow(macro: m),
                if (s.note != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(s.note!, style: t.label.copyWith(color: c.warning)),
                ],
                if (!s.hasGoal)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onSetTargets,
                      child: const Text('Set targets'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMacroRow extends StatelessWidget {
  const _MiniMacroRow({required this.macro});

  final MacroBarData macro;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final color = switch (macro.kind) {
      MacroKind.protein => c.protein,
      MacroKind.carbs => c.carbs,
      MacroKind.fat => c.fat,
    };
    final target = macro.targetG;
    final hasTarget = target != null && target > 0;
    final amount = hasTarget
        ? '${Formatters.integer(macro.consumedG)}/${Formatters.grams(target)}'
        : Formatters.grams(macro.consumedG);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${macro.label} ${Formatters.grams(macro.consumedG)}'
          '${hasTarget ? ' of ${Formatters.grams(target)}' : ', no target'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(macro.label, style: t.label.copyWith(color: c.ink)),
            ),
            Expanded(
              child: FitProgressBar(
                fraction: hasTarget ? macro.consumedG / target : null,
                color: color,
                height: 5,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(amount, style: t.label),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.group,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final MealGroupViewData group;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      header: Row(
        children: [
          Expanded(child: Text(group.title, style: t.cardTitle)),
          Text(group.totalLabel, style: t.label),
          IconButton(
            tooltip: 'Add to ${group.title}',
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: group.entries.isEmpty
            ? EmptyState(
                message: 'Nothing logged yet',
                actionLabel: 'Add food',
                onAction: onAdd,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < group.entries.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _EntryRow(
                      entry: group.entries[i],
                      deleteBackground: c.error,
                      deleteIconColor: c.surface,
                      onTap: () => onEdit(group.entries[i].id),
                      onDelete: () => onDelete(group.entries[i].id),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.deleteBackground,
    required this.deleteIconColor,
    required this.onTap,
    required this.onDelete,
  });

  final EntryRowData entry;
  final Color deleteBackground;
  final Color deleteIconColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: ColoredBox(
        color: deleteBackground,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Icon(Icons.delete_outline, color: deleteIconColor),
          ),
        ),
      ),
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Delete'): onDelete,
        },
        child: ListRow(
          title: entry.name,
          subtitle: entry.detail,
          value: entry.kcal,
          unit: 'kcal',
          onTap: onTap,
        ),
      ),
    );
  }
}
