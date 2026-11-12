import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/workout_providers.dart';
import '../../data/workout_models.dart';
import '../../domain/strength_stats.dart';
import 'session_detail_view.dart';

/// A finished session: totals, exercises (under the names they had then)
/// and sets. It can be deleted, which also deletes its sets.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId));
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final s = session.value;

    final history = ref.watch(completedWorkoutHistoryProvider).value;
    final records = s == null || history == null
        ? const <NewPr>[]
        : StrengthStats.newPrs(
            s.toLogged(),
            history.map((item) => item.toLogged()),
          );
    return SessionDetailView(
      onExerciseHistory: (id) => context.push(Routes.exerciseHistory(id)),
      loading: !session.hasValue && !session.hasError,
      data: s == null
          ? null
          : sessionDetailViewData(s, units, records: records),
      onDelete: () async {
        final ok = await showConfirmDialog(
          context,
          title: 'Delete this session?',
          message:
              "Its exercises and sets are deleted too. This can't be undone.",
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await ref.read(workoutRepositoryProvider).deleteSession(sessionId);
        if (context.mounted) context.go(Routes.workouts);
      },
    );
  }
}

SessionDetailViewData sessionDetailViewData(
  SessionDetail s,
  UnitSystem units, {
  List<NewPr> records = const [],
}) {
  final summary = s.summary;
  final start = s.session.startedAt, end = s.session.completedAt;
  final time = DateFormat('HH:mm');
  final unit = Units.weightUnit(units);
  String load(double kg) {
    final v = Units.weightForDisplay(kg, units);
    return v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  return SessionDetailViewData(
    title: s.session.name ?? 'Workout',
    when: [
      DateFormat('EEE d MMM y').format(start),
      end == null
          ? time.format(start)
          : '${time.format(start)}–${time.format(end)}',
    ].join(' · '),
    stats: [
      StatItem(
        label: 'Duration',
        value: summary.duration == null
            ? Formatters.unknownValue
            : '${summary.duration!.inMinutes}',
        unit: summary.duration == null ? null : 'min',
      ),
      StatItem(label: 'Sets', value: '${summary.completedSets}'),
      StatItem(
        label: 'Volume',
        value: Formatters.integer(
          Units.weightForDisplay(summary.totalVolumeKg, units),
        ),
        unit: unit,
      ),
    ],
    notes: s.session.notes,
    hasNewPr: records.isNotEmpty,
    exercises: [
      for (final (exerciseIndex, e) in s.exercises.indexed)
        ExerciseSetsData(
          name: e.name,
          exerciseId: e.entry.exerciseId,
          sets: [
            for (final (setIndex, x) in e.sets.indexed)
              SetLineData(
                number: x.setNumber,
                completed: x.completed,
                newPr: records.any(
                  (r) =>
                      r.exerciseIndex == exerciseIndex &&
                      r.setIndex == setIndex,
                ),
                text: _setText(
                  x.repetitions,
                  x.weightKg == null ? null : '${load(x.weightKg!)} $unit',
                  bodyweight: e.isBodyweight,
                ),
              ),
          ],
        ),
    ],
  );
}

/// "8 × 60 kg"; bodyweight: "12 reps" or "12 reps · +10 kg".
String _setText(int? reps, String? load, {required bool bodyweight}) {
  final r = reps?.toString() ?? Formatters.unknownValue;
  if (bodyweight) {
    return load == null ? '$r reps' : '$r reps · +$load';
  }
  return load == null ? '$r reps' : '$r × $load';
}
