import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/diary_providers.dart';
import '../../data/local/food_repository.dart';
import '../../domain/nutrition_math.dart';
import 'day_overview_view.dart';
import 'day_overview_view_data.dart';

/// Local date keys with entries in the week starting on the keyed day.
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

/// The Nutrition tab: one day's diary against the targets in effect that day.
///
/// Deleting an entry hides it at once and only removes it from the database
/// when the "Undo" snackbar closes without being used, so undo restores the
/// exact entry (same snapshot, same time).
class DayOverviewScreen extends ConsumerStatefulWidget {
  const DayOverviewScreen({super.key, this.date});

  final DateTime? date;

  @override
  ConsumerState<DayOverviewScreen> createState() => _DayOverviewScreenState();
}

class _DayOverviewScreenState extends ConsumerState<DayOverviewScreen> {
  late DateTime _selected = Dates.startOfDay(widget.date ?? DateTime.now());
  final _pendingDeletes = <int>{};

  @override
  void didUpdateWidget(DayOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final date = widget.date;
    if (date != null && date != oldWidget.date) {
      _selected = Dates.startOfDay(date);
    }
  }

  DateTime get _today => Dates.startOfDay(DateTime.now());

  void _select(DateTime day) => setState(() => _selected = day);

  void _shiftWeek(int weeks) {
    final target = Dates.addDays(_selected, 7 * weeks);
    _select(target.isAfter(_today) ? _today : target);
  }

  void _delete(int id) {
    final repository = ref.read(foodRepositoryProvider);
    setState(() => _pendingDeletes.add(id));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Entry deleted'),
            persist: false,
            action: SnackBarAction(label: 'UNDO', onPressed: () {}),
          ),
        )
        .closed
        .then((reason) async {
          if (reason != SnackBarClosedReason.action) {
            await repository.deleteEntry(id);
          }
          if (mounted) setState(() => _pendingDeletes.remove(id));
        });
  }

  @override
  Widget build(BuildContext context) {
    final key = Dates.localDateKey(_selected);
    final week = Dates.weekOf(_selected);
    final loggedDays = ref.watch(
      _loggedDaysProvider(Dates.localDateKey(week.first)),
    );
    final entries = ref.watch(diaryEntriesProvider(key));
    final targets = ref.watch(targetsForDateProvider(key));

    final DayBody body;
    if (entries.hasError || targets.hasError) {
      body = const DayError("Couldn't load this day.");
    } else if (!entries.hasValue || !targets.hasValue) {
      body = const DayLoading();
    } else {
      body = _loaded(
        entries.requireValue
            .where((e) => !_pendingDeletes.contains(e.id))
            .toList(),
        targets.requireValue,
      );
    }

    return DayOverviewView(
      data: DayOverviewViewData(
        week: week,
        selected: _selected,
        today: _today,
        weekLabel: _weekLabel(week),
        canGoToNextWeek: !Dates.addDays(week.first, 7).isAfter(_today),
        daysWithEntries: loggedDays.value ?? const {},
        body: body,
      ),
      onSelectDay: _select,
      onPreviousWeek: () => _shiftWeek(-1),
      onNextWeek: () => _shiftWeek(1),
      onSearch: () => context.push(Routes.foodSearch(date: _selected)),
      onCreateCustomFood: () => context.push(Routes.newCustomFood),
      onAddToMeal: (meal) =>
          context.push(Routes.foodSearch(meal: meal, date: _selected)),
      onEditEntry: (id) => context.push(Routes.editEntry(id)),
      onDeleteEntry: _delete,
      onSetTargets: () => context.go(Routes.targets),
      onRetry: () => ref
        ..invalidate(diaryEntriesProvider(key))
        ..invalidate(targetsForDateProvider(key)),
    );
  }

  static DayLoaded _loaded(List<FoodEntry> entries, NutritionTarget? target) {
    final summary = DailyNutritionSummary([
      for (final e in entries)
        LoggedNutrients(
          meal: e.mealType,
          nutrients: FoodRepository.entryNutrients(e),
        ),
    ]);
    final total = summary.total;
    final split = summary.split;

    final String? note;
    if (total.entriesMissingKcal > 0) {
      note = _plural(total.entriesMissingKcal, 'has no calorie data');
    } else if (total.entriesMissingMacros > 0) {
      note = _plural(total.entriesMissingMacros, 'has incomplete macro data');
    } else {
      note = null;
    }

    return DayLoaded(
      summary: DaySummaryViewData(
        eatenKcal: total.kcal,
        goalKcal: target?.calories.toDouble(),
        proteinKcal: split.proteinKcal,
        carbsKcal: split.carbsKcal,
        fatKcal: split.fatKcal,
        unknownKcal: split.unknownKcal,
        macros: [
          MacroBarData(
            kind: MacroKind.protein,
            label: 'Prot.',
            consumedG: total.proteinG,
            targetG: target?.proteinG,
          ),
          MacroBarData(
            kind: MacroKind.carbs,
            label: 'Carbs',
            consumedG: total.carbsG,
            targetG: target?.carbsG,
          ),
          MacroBarData(
            kind: MacroKind.fat,
            label: 'Fat',
            consumedG: total.fatG,
            targetG: target?.fatG,
          ),
        ],
        note: note,
      ),
      meals: [
        for (final meal in MealType.values)
          MealGroupViewData(
            meal: meal,
            title: mealTitle(meal),
            // Empty meals show no total: a lone "—" next to "+" read as a
            // minus button.
            totalLabel: summary.byMeal[meal]!.isEmpty
                ? ''
                : Formatters.energy(summary.byMeal[meal]!.kcal),
            entries: [
              for (final e in entries.where((e) => e.mealType == meal))
                EntryRowData(
                  id: e.id,
                  name: e.nameSnapshot,
                  detail: [
                    quantityLabel(e.quantity, e.quantityUnit),
                    ?e.brandSnapshot,
                  ].join(' · '),
                  kcal: Formatters.integer(e.kcal),
                ),
            ],
          ),
      ],
    );
  }

  static String _plural(int n, String predicate) => n == 1
      ? '1 entry $predicate'
      : '$n entries ${predicate.replaceFirst('has', 'have')}';

  static String _weekLabel(List<DateTime> week) {
    final first = week.first, last = week.last;
    final end = DateFormat('d MMM').format(last);
    final start = first.month == last.month
        ? '${first.day}'
        : DateFormat('d MMM').format(first);
    return '$start – $end';
  }
}

String mealTitle(MealType meal) => switch (meal) {
  MealType.breakfast => 'Breakfast',
  MealType.lunch => 'Lunch',
  MealType.dinner => 'Dinner',
  MealType.snack => 'Snacks',
};

/// "200 g", "250 ml", "1 serving", "1.5 servings".
String quantityLabel(double quantity, String unitCode) {
  final q = quantity == quantity.roundToDouble()
      ? quantity.round().toString()
      : quantity.toStringAsFixed(1);
  return switch (unitCode) {
    'g' => '$q g',
    'ml' => '$q ml',
    _ => quantity == 1 ? '1 serving' : '$q servings',
  };
}
