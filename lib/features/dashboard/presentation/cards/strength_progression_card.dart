import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../workouts/application/workout_providers.dart';
import '../../../workouts/data/workout_models.dart';
import '../../../workouts/domain/workout_math.dart';
import 'workout_summary_card.dart' show dashboardSessionLimit;

/// Home "Strength progression": for the exercises trained most often, the
/// best set of the latest session against the one before.
class StrengthProgressionCard extends ConsumerWidget {
  const StrengthProgressionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(recentSessionsProvider(dashboardSessionLimit));
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    if (sessions.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your workouts.",
          onRetry: () =>
              ref.invalidate(recentSessionsProvider(dashboardSessionLimit)),
        ),
      );
    }
    return StrengthProgressionCardView(
      rows: sessions.hasValue
          ? strengthRows(sessions.requireValue, units)
          : null,
      onTap: () => context.go(Routes.progress),
    );
  }
}

enum Trend { up, same, down }

class StrengthRow {
  const StrengthRow({
    required this.name,
    required this.best,
    required this.change,
    required this.trend,
  });

  final String name;

  /// "100 kg × 5" or "12 reps"
  final String best;

  /// "+2.5 kg", "+2 reps", "Same"
  final String change;
  final Trend trend;
}

/// Up to three exercises done in at least two of [sessions], most frequent
/// first, comparing the best set of their last two sessions.
List<StrengthRow> strengthRows(List<SessionDetail> sessions, UnitSystem units) {
  final logged = [for (final s in sessions) s.toLogged()];
  final counts = <int, int>{};
  final names = <int, String>{};
  // Sessions are newest first, so the first name seen is the latest.
  for (final s in logged) {
    for (final id in {for (final e in s.exercises) e.exerciseId}) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    for (final e in s.exercises) {
      names.putIfAbsent(e.exerciseId, () => e.name);
    }
  }
  final ids =
      (counts.entries.where((e) => e.value >= 2).toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .map((e) => e.key);

  final unit = Units.weightUnit(units);
  String kg(double v) => Units.weightForDisplay(
    v,
    units,
  ).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  final rows = <StrengthRow>[];
  for (final id in ids) {
    final history = WorkoutMath.exerciseHistory(id, logged);
    if (history.length < 2) continue;
    final prev = history[history.length - 2], last = history.last;
    final a = prev.bestSet, b = last.bestSet;
    if (a == null || b == null) continue;

    final String change;
    final Trend trend;
    final wa = a.weightKg, wb = b.weightKg;
    if (wa != null && wb != null && wa != wb) {
      final d = wb - wa;
      change = '${d > 0 ? '+' : '−'}${kg(d.abs())} $unit';
      trend = d > 0 ? Trend.up : Trend.down;
    } else if (a.reps != b.reps) {
      final d = b.reps - a.reps;
      change = '${d > 0 ? '+' : '−'}${d.abs()} reps';
      trend = d > 0 ? Trend.up : Trend.down;
    } else {
      change = 'Same';
      trend = Trend.same;
    }
    rows.add(
      StrengthRow(
        name: names[id]!,
        best: wb == null ? '${b.reps} reps' : '${kg(wb)} $unit × ${b.reps}',
        change: change,
        trend: trend,
      ),
    );
    if (rows.length == 3) break;
  }
  return rows;
}

/// Pure layout for the strength progression card.
class StrengthProgressionCardView extends StatelessWidget {
  const StrengthProgressionCardView({
    super.key,
    required this.rows,
    required this.onTap,
  });

  /// Null while loading.
  final List<StrengthRow>? rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final rows = this.rows;
    return SectionCard(
      onTap: onTap,
      header: const CardHeader(
        title: 'Strength progression',
        subtitle: TextSpan(text: 'Best set vs the session before'),
      ),
      child: rows == null
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            )
          : rows.isEmpty
          ? Text(
              'Do the same exercise in two workouts to see your progress.',
              style: t.label,
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.line),
                  ListRow(
                    title: rows[i].name,
                    subtitle: rows[i].best,
                    trailing: Text(
                      rows[i].change,
                      style: t.bodyStrong.copyWith(
                        color: switch (rows[i].trend) {
                          Trend.up => c.success,
                          Trend.same => c.inkMuted,
                          Trend.down => c.ink,
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
