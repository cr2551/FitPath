import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/enums.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/metabolic_calculator.dart';
import 'targets_view.dart';

/// Shows the targets in effect today and records new ones, either the
/// calculated suggestion (source `calculated`) or the user's own values
/// (source `user`). Every change is a NEW row effective from today, so past
/// days keep showing the targets that applied then.
class TargetsScreen extends ConsumerStatefulWidget {
  const TargetsScreen({super.key});

  @override
  ConsumerState<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends ConsumerState<TargetsScreen> {
  bool _initialized = false;
  double? _kcal;
  double? _protein;
  double? _carbs;
  double? _fat;
  bool _saving = false;

  void _init(NutritionTarget? t) {
    _initialized = true;
    _kcal = t?.calories.toDouble();
    _protein = t?.proteinG;
    _carbs = t?.carbsG;
    _fat = t?.fatG;
  }

  Future<void> _store({
    required int calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    required TargetSource source,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .setTargets(
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            source: source,
          );
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(Routes.profile);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your targets.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentTargetsProvider);
    final estimates = ref.watch(profileEstimatesProvider);

    TargetsViewData? data;
    String? error;
    CalorieTarget? kcal;
    MacroTargets? macros;
    if (current.hasError || estimates.hasError) {
      error = "Couldn't load your targets.";
    } else if (current.hasValue && estimates.hasValue) {
      final t = current.requireValue;
      if (!_initialized) _init(t);
      final e = estimates.requireValue;
      kcal = e.calorieTarget.value;
      macros = e.macros.value;
      data = TargetsViewData(
        current: t == null
            ? null
            : _summary(t.calories, t.proteinG, t.carbsG, t.fatG),
        currentSource: t == null
            ? null
            : '${t.source == TargetSource.user ? 'Set by you' : 'Calculated'}'
                  ' · since ${DateFormat('d MMM y').format(Dates.fromLocalDateKey(t.effectiveFrom))}',
        suggestion: kcal == null
            ? null
            : _summary(
                kcal.kcal,
                macros?.proteinG.toDouble(),
                macros?.carbsG.toDouble(),
                macros?.fatG.toDouble(),
              ),
        suggestionNote: kcal == null
            ? 'Add your age, height, weight and activity level to get a '
                  'suggestion.'
            : kcal.guardrailApplied
            ? 'Adjusted to stay within a safe range.'
            : 'Based on your details and main goal.',
        initialKcal: _kcal,
        initialProtein: _protein,
        initialCarbs: _carbs,
        initialFat: _fat,
        canSave: _kcal != null,
        saving: _saving,
      );
    }

    return TargetsView(
      data: data,
      error: error,
      callbacks: TargetsCallbacks(
        onKcal: (v) => setState(() => _kcal = v),
        onProtein: (v) => setState(() => _protein = v),
        onCarbs: (v) => setState(() => _carbs = v),
        onFat: (v) => setState(() => _fat = v),
        onUseSuggestion: () {
          if (kcal == null) return;
          _store(
            calories: kcal.kcal,
            proteinG: macros?.proteinG.toDouble(),
            carbsG: macros?.carbsG.toDouble(),
            fatG: macros?.fatG.toDouble(),
            source: TargetSource.calculated,
          );
        },
        onEditDetails: () => context.push(Routes.profileDetails),
        onSave: () => _store(
          calories: _kcal!.round(),
          proteinG: _protein,
          carbsG: _carbs,
          fatG: _fat,
          source: TargetSource.user,
        ),
        onRetry: () => ref.invalidate(profileProvider),
      ),
    );
  }

  static String _summary(int kcal, double? p, double? c, double? f) => [
    Formatters.energy(kcal),
    if (p != null) 'P ${Formatters.integer(p)}',
    if (c != null) 'C ${Formatters.integer(c)}',
    if (f != null) 'F ${Formatters.integer(f)} g',
  ].join(' · ');
}
