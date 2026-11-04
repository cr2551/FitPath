import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../profile/application/profile_providers.dart';
import 'goals_view.dart';

const _weightGoals = {GoalType.loseWeight, GoalType.buildMuscle};

/// Edits the primary and secondary goals without losing history: a changed
/// primary goal is a new row and the old one is deactivated.
///
/// After the primary goal TYPE changes, the user is asked whether to apply
/// that goal's dashboard preset. Keeping the current layout is the default,
/// so a custom dashboard is never replaced silently. Nutrition targets are
/// not changed here (see the targets screen).
class GoalsSettingsScreen extends ConsumerStatefulWidget {
  const GoalsSettingsScreen({super.key});

  @override
  ConsumerState<GoalsSettingsScreen> createState() =>
      _GoalsSettingsScreenState();
}

class _GoalsSettingsScreenState extends ConsumerState<GoalsSettingsScreen> {
  bool _initialized = false;
  FitnessGoal? _current;
  GoalType? _primary;
  final _secondary = <GoalType>{};
  double? _targetWeightKg;
  DateTime? _targetDate;
  bool _saving = false;

  void _init(List<FitnessGoal> goals) {
    _initialized = true;
    _current = goals.where((g) => g.isPrimary).firstOrNull;
    _primary = _current?.goalType;
    _targetWeightKg = _current?.targetWeightKg;
    _targetDate = _current?.targetDate;
    _secondary.addAll(goals.where((g) => !g.isPrimary).map((g) => g.goalType));
  }

  bool get _hasWeightTarget => _weightGoals.contains(_primary);

  Future<void> _save() async {
    final primary = _primary;
    if (primary == null) return;
    setState(() => _saving = true);
    final profile = ref.read(profileRepositoryProvider);
    final current = _current;
    final weight = _hasWeightTarget ? _targetWeightKg : null;
    final date = _hasWeightTarget ? _targetDate : null;
    final typeChanged = current?.goalType != primary;
    try {
      await profile.transaction(() async {
        if (typeChanged ||
            current?.targetWeightKg != weight ||
            current?.targetDate != date) {
          await profile.setPrimaryGoal(
            primary,
            targetWeightKg: weight,
            targetDate: date,
          );
        }
        await profile.setSecondaryGoals(_secondary.difference({primary}));
      });
      if (!mounted) return;

      if (typeChanged) {
        final apply = await showConfirmDialog(
          context,
          title: 'Update your Home dashboard?',
          message:
              'There is a suggested layout for "${goalLabels[primary]}". '
              'Your current layout stays unless you choose to replace it.',
          confirmLabel: 'Use new layout',
          cancelLabel: 'Keep current',
        );
        if (apply) {
          await ref.read(dashboardRepositoryProvider).applyPreset(primary);
        }
      }
      if (mounted) {
        context.canPop() ? context.pop() : context.go(Routes.profile);
      }
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your goals.")),
      );
    }
  }

  Future<void> _pickDate() async {
    final today = Dates.startOfDay(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? Dates.addDays(today, 90),
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(activeGoalsProvider);
    final units = ref.watch(unitSystemProvider);

    GoalsViewData? data;
    String? error;
    var system = UnitSystem.metric;
    if (goals.hasError || units.hasError) {
      error = "Couldn't load your goals.";
    } else if (goals.hasValue && units.hasValue) {
      if (!_initialized) _init(goals.requireValue);
      system = units.requireValue;
      const kg = PlausibleRanges.weightKg;
      final imperial = system == UnitSystem.imperial;
      data = GoalsViewData(
        primary: _primary,
        secondary: _secondary,
        showTargetWeight: _hasWeightTarget,
        targetWeight: _targetWeightKg == null
            ? null
            : Units.weightForDisplay(_targetWeightKg!, system),
        weightUnit: Units.weightUnit(system),
        weightRange: imperial
            ? ValueRange(
                Units.kgToLb(kg.min).ceilToDouble(),
                Units.kgToLb(kg.max).floorToDouble(),
              )
            : kg,
        targetDateLabel: _targetDate == null
            ? null
            : DateFormat('d MMM y').format(_targetDate!),
        canSave: _primary != null,
        saving: _saving,
      );
    }

    return GoalsView(
      data: data,
      error: error,
      callbacks: GoalsCallbacks(
        onPrimary: (g) => setState(() {
          _primary = g;
          _secondary.remove(g);
        }),
        onToggleSecondary: (g) => setState(
          () =>
              _secondary.contains(g) ? _secondary.remove(g) : _secondary.add(g),
        ),
        onTargetWeight: (v) => setState(() {
          // Optional field: empty or out-of-range input means no target.
          _targetWeightKg = v == null ? null : Units.weightFromInput(v, system);
        }),
        onPickTargetDate: _pickDate,
        onClearTargetDate: () => setState(() => _targetDate = null),
        onSave: _save,
        onRetry: () => ref.invalidate(activeGoalsProvider),
      ),
    );
  }
}
