import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';
import 'workout_summary_card.dart' show dashboardSessionLimit;

/// Home "Recent sessions": the last three completed workouts, each opening
/// its detail.
class RecentSessionsCard extends ConsumerWidget {
  const RecentSessionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSessionsProvider(dashboardSessionLimit));
    if (sessions.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your workouts.",
          onRetry: () =>
              ref.invalidate(recentSessionsProvider(dashboardSessionLimit)),
        ),
      );
    }
    return RecentSessionsCardView(
      rows: sessions.hasValue ? recentSessionRows(sessions.requireValue) : null,
      onOpen: (id) => context.go(Routes.sessionDetail(id)),
      onStart: () => context.go(Routes.workouts),
    );
  }
}

class RecentSessionRow {
  const RecentSessionRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
  });

  final int id;
  final String title;

  /// "Mon 2 Nov · 42 min"
  final String subtitle;

  /// "5 ex · 18 sets"
  final String detail;
}

/// The three newest sessions (the list is newest first).
List<RecentSessionRow> recentSessionRows(List<SessionDetail> sessions) => [
  for (final s in sessions.take(3)) _row(s),
];

RecentSessionRow _row(SessionDetail s) {
  final summary = s.summary;
  final minutes = summary.duration?.inMinutes;
  return RecentSessionRow(
    id: s.id,
    title: s.session.name ?? 'Workout',
    subtitle: [
      DateFormat('EEE d MMM').format(s.session.startedAt),
      if (minutes != null) '$minutes min',
    ].join(' · '),
    detail: '${summary.exerciseCount} ex · ${summary.completedSets} sets',
  );
}

/// Pure layout for the recent sessions card.
class RecentSessionsCardView extends StatelessWidget {
  const RecentSessionsCardView({
    super.key,
    required this.rows,
    required this.onOpen,
    required this.onStart,
  });

  /// Null while loading.
  final List<RecentSessionRow>? rows;
  final ValueChanged<int> onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    return SectionCard(
      header: const CardHeader(title: 'Recent sessions'),
      child: rows == null
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            )
          : rows.isEmpty
          ? EmptyState(
              message: 'No workouts yet.',
              actionLabel: 'Start one',
              onAction: onStart,
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.fitColors.line),
                  ListRow(
                    title: rows[i].title,
                    subtitle: rows[i].subtitle,
                    value: rows[i].detail,
                    onTap: () => onOpen(rows[i].id),
                  ),
                ],
              ],
            ),
    );
  }
}
