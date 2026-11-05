import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/workout_providers.dart';
import '../data/workout_models.dart';
import 'widgets/session_list_tile.dart';
import 'workouts_view.dart';

/// The Workouts tab: resume or discard the session in progress, start a
/// new one, and the most recent completed sessions.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider);
    final recent = ref.watch(recentSessionsProvider(10));
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final repo = ref.read(workoutRepositoryProvider);

    WorkoutsViewData? data;
    String? error;
    if (active.hasError || recent.hasError) {
      error = "Couldn't load your workouts.";
    } else if (active.hasValue && recent.hasValue) {
      final a = active.requireValue;
      data = WorkoutsViewData(
        active: a == null ? null : activeSessionData(a),
        recent: [
          for (final s in recent.requireValue) sessionTileData(s, units),
        ],
      );
    }

    Future<void> start() async {
      final current = active.value;
      if (current != null) {
        final replace = await showConfirmDialog(
          context,
          title: 'Discard the workout in progress?',
          message:
              'Only one workout can be open. Discarding "${sessionTitle(current)}" '
              "can't be undone.",
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (!replace) return;
        await repo.discardSession(current.id);
      }
      if (!context.mounted) return;
      final name = await showStartWorkoutDialog(context);
      if (name == null) return;
      await repo.startSession(name: name);
      if (context.mounted) context.go(Routes.activeSession);
    }

    return WorkoutsView(
      data: data,
      error: error,
      callbacks: WorkoutsCallbacks(
        onStart: start,
        onResume: () => context.go(Routes.activeSession),
        onDiscard: () async {
          final current = active.value;
          if (current == null) return;
          final ok = await showConfirmDialog(
            context,
            title: 'Discard this workout?',
            message: "Its exercises and sets won't be saved.",
            confirmLabel: 'Discard',
            destructive: true,
          );
          if (ok) await repo.discardSession(current.id);
        },
        onOpenSession: (id) => context.go(Routes.sessionDetail(id)),
        onRetry: () => ref
          ..invalidate(activeSessionProvider)
          ..invalidate(recentSessionsProvider(10)),
      ),
    );
  }
}

String sessionTitle(SessionDetail s) => s.session.name ?? 'Workout';

ActiveSessionData activeSessionData(SessionDetail s) {
  final sets = [for (final e in s.exercises) ...e.sets];
  final done = sets.where((x) => x.completed).length;
  final exercises = s.exercises.length;
  return ActiveSessionData(
    title: sessionTitle(s),
    summary: [
      'Started ${DateFormat('HH:mm').format(s.session.startedAt)}',
      '$exercises ${exercises == 1 ? 'exercise' : 'exercises'}',
      '$done of ${sets.length} sets done',
    ].join(' · '),
    progress: sets.isEmpty ? null : done / sets.length,
  );
}

/// "Mon 2 Nov · 42 min · 9,840 kg" and "5 ex · 18 sets".
SessionTileData sessionTileData(SessionDetail s, UnitSystem units) {
  final summary = s.summary;
  final minutes = summary.duration?.inMinutes;
  final volume = summary.totalVolumeKg;
  return SessionTileData(
    id: s.id,
    title: sessionTitle(s),
    subtitle: [
      DateFormat('EEE d MMM').format(s.session.startedAt),
      if (minutes != null) '$minutes min',
      if (volume > 0)
        '${Formatters.integer(Units.weightForDisplay(volume, units))} '
            '${Units.weightUnit(units)}',
    ].join(' · '),
    detail: '${summary.exerciseCount} ex · ${summary.completedSets} sets',
  );
}
