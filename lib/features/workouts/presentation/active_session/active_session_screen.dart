import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/workout_providers.dart';
import '../../data/workout_models.dart';
import 'active_session_view.dart';
import 'active_session_view_data.dart';

/// The workout in progress. Every change is saved as it happens, so the
/// session survives leaving the screen or restarting the app.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Refresh the elapsed time.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save that change.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider);
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final repo = ref.read(workoutRepositoryProvider);
    final session = active.value;

    double? toKg(double? load) =>
        load == null ? null : Units.weightFromInput(load, units);

    Future<void> finish(SessionDetail s) async {
      final completed = s.exercises
          .expand((e) => e.sets)
          .where((x) => x.completed)
          .length;
      final ok = await showConfirmDialog(
        context,
        title: completed == 0 ? 'No sets are marked done' : 'Finish workout?',
        message: completed == 0
            ? 'Tick the sets you did so they count. Finish anyway?'
            : 'It moves to your history. Sets not marked done are not '
                  'counted.',
        confirmLabel: 'Finish',
      );
      if (!ok) return;
      await _guard(() => repo.completeSession(s.id));
      if (context.mounted) context.go(Routes.sessionDetail(s.id));
    }

    Future<void> discard(SessionDetail s) async {
      final ok = await showConfirmDialog(
        context,
        title: 'Discard this workout?',
        message: "Its exercises and sets won't be saved.",
        confirmLabel: 'Discard',
        destructive: true,
      );
      if (!ok) return;
      await _guard(() => repo.discardSession(s.id));
      if (context.mounted) context.go(Routes.workouts);
    }

    Future<void> addExercise(SessionDetail s) async {
      final id = await context.push<int>(Routes.exercisePicker);
      if (id == null) return;
      await _guard(() async {
        final entry = await repo.addExercise(s.id, id);
        await repo.addSet(entry);
      });
    }

    return ActiveSessionView(
      loading: active.isLoading && session == null,
      data: session == null
          ? null
          : activeSessionViewData(session, units, DateTime.now()),
      callbacks: ActiveSessionCallbacks(
        onRename: (name) => _guard(() => repo.renameSession(session!.id, name)),
        onNotes: (notes) =>
            _guard(() => repo.setSessionNotes(session!.id, notes)),
        onAddExercise: () => addExercise(session!),
        onMoveExercise: (id, delta) {
          final ids = [for (final e in session!.exercises) e.id];
          final i = ids.indexOf(id);
          final j = i + delta;
          if (i < 0 || j < 0 || j >= ids.length) return;
          ids
            ..removeAt(i)
            ..insert(j, id);
          _guard(() => repo.reorderExercises(session.id, ids));
        },
        onRemoveExercise: (id) => _guard(() => repo.removeExercise(id)),
        onAddSet: (exerciseId) {
          final last = _lastSet(session, exerciseId);
          _guard(
            () => repo.addSet(
              exerciseId,
              reps: last?.repetitions,
              weightKg: last?.weightKg,
            ),
          );
        },
        onDuplicateSet: (setId) {
          final s = _findSet(session, setId);
          if (s == null) return;
          _guard(
            () => repo.addSet(
              s.workoutExerciseId,
              reps: s.repetitions,
              weightKg: s.weightKg,
            ),
          );
        },
        onRemoveSet: (setId) => _guard(() => repo.removeSet(setId)),
        onSetValues: (setId, reps, load) => _guard(
          () => repo.updateSet(
            setId,
            reps: Value(reps),
            weightKg: Value(toKg(load)),
          ),
        ),
        onSetCompleted: (setId, done) =>
            _guard(() => repo.updateSet(setId, completed: Value(done))),
        onFinish: () => finish(session!),
        onDiscard: () => discard(session!),
        onBackToWorkouts: () => context.go(Routes.workouts),
      ),
    );
  }
}

WorkoutSet? _findSet(SessionDetail? s, int setId) {
  for (final e in s?.exercises ?? const <SessionExercise>[]) {
    for (final x in e.sets) {
      if (x.id == setId) return x;
    }
  }
  return null;
}

WorkoutSet? _lastSet(SessionDetail? s, int workoutExerciseId) => s?.exercises
    .where((e) => e.id == workoutExerciseId)
    .firstOrNull
    ?.sets
    .lastOrNull;

/// Maps the session to view data with loads in the user's units.
ActiveSessionViewData activeSessionViewData(
  SessionDetail s,
  UnitSystem units,
  DateTime now,
) {
  final sets = [for (final e in s.exercises) ...e.sets];
  return ActiveSessionViewData(
    sessionId: s.id,
    name: s.session.name ?? '',
    notes: s.session.notes ?? '',
    elapsed: formatElapsed(now.difference(s.session.startedAt)),
    loadUnit: Units.weightUnit(units),
    maxLoad: Units.weightForDisplay(1000, units),
    completedSets: sets.where((x) => x.completed).length,
    totalSets: sets.length,
    exercises: [
      for (final e in s.exercises)
        ExerciseBlockData(
          id: e.id,
          name: e.name,
          isBodyweight: e.isBodyweight,
          sets: [
            for (final x in e.sets)
              SetRowData(
                id: x.id,
                number: x.setNumber,
                reps: x.repetitions,
                load: x.weightKg == null
                    ? null
                    : Units.weightForDisplay(x.weightKg!, units),
                completed: x.completed,
              ),
          ],
        ),
    ],
  );
}

/// "4:05", "42:10", "1:05:30".
String formatElapsed(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
