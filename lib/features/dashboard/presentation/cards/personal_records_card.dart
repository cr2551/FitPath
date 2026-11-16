import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';
import '../../../workouts/domain/strength_stats.dart';
import '../../../workouts/presentation/widgets/pr_label.dart';
import 'card_loading.dart';
import 'personal_records_card_view.dart';

/// Home "Personal records": the latest records, one per exercise and
/// session. Tapping one opens that exercise's history.
class PersonalRecordsCard extends ConsumerWidget {
  const PersonalRecordsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(completedWorkoutHistoryProvider);
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    if (sessions.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your records.",
          onRetry: () => ref.invalidate(completedWorkoutHistoryProvider),
        ),
      );
    }
    if (!sessions.hasValue) return const CardLoading();
    return PersonalRecordsCardView(
      rows: latestPrRows(sessions.requireValue, units),
      onExercise: (id) => context.push(Routes.exerciseHistory(id)),
    );
  }
}

/// Which record to show when one set beat several.
const _kindOrder = [
  PrKind.heaviestLoad,
  PrKind.oneRepMax,
  PrKind.setVolume,
  PrKind.repsAtLoad,
  PrKind.mostReps,
];

/// The newest records from completed sessions ([newestFirst]), at most
/// [limit], one per exercise per session.
List<PrCardRow> latestPrRows(
  List<SessionDetail> newestFirst,
  UnitSystem units, {
  int limit = 3,
}) {
  final logged = [for (final s in newestFirst) s.toLogged()];
  final rows = <PrCardRow>[];
  for (final session in logged) {
    final best = <int, NewPr>{};
    for (final pr in StrengthStats.newPrs(session, logged)) {
      final kept = best[pr.exerciseId];
      if (kept == null ||
          _kindOrder.indexOf(pr.kind) < _kindOrder.indexOf(kept.kind)) {
        best[pr.exerciseId] = pr;
      }
    }
    for (final pr in best.values) {
      if (rows.length == limit) return rows;
      rows.add(
        PrCardRow(
          exerciseId: pr.exerciseId,
          exercise: session.exercises[pr.exerciseIndex].name,
          record: prRecordLabel(pr, units),
          date: DateFormat('d MMM').format(session.startedAt.toLocal()),
        ),
      );
    }
  }
  return rows;
}
