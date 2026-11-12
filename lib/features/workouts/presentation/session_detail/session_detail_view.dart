import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class SessionDetailViewData {
  const SessionDetailViewData({
    required this.title,
    required this.when,
    required this.stats,
    required this.notes,
    required this.exercises,
    this.hasNewPr = false,
  });

  final String title;

  /// "Mon 2 Nov 2026 · 18:05–18:47"
  final String when;

  /// Duration, sets, volume.
  final List<StatItem> stats;
  final String? notes;
  final List<ExerciseSetsData> exercises;
  final bool hasNewPr;
}

class ExerciseSetsData {
  const ExerciseSetsData({
    required this.name,
    required this.sets,
    this.exerciseId,
  });

  /// The name as it was when the session was logged.
  final String name;
  final int? exerciseId;
  final List<SetLineData> sets;
}

class SetLineData {
  const SetLineData({
    required this.number,
    required this.text,
    required this.completed,
    this.newPr = false,
  });

  final int number;

  /// "8 × 60 kg", "12 reps", "12 reps · +10 kg".
  final String text;
  final bool completed;
  final bool newPr;
}

/// Pure layout for a completed session: header with totals, then each
/// exercise with its sets.
class SessionDetailView extends StatelessWidget {
  const SessionDetailView({
    super.key,
    required this.data,
    required this.loading,
    required this.onDelete,
    this.onExerciseHistory,
  });

  /// Null when the session does not exist (and not [loading]).
  final SessionDetailViewData? data;
  final bool loading;
  final VoidCallback onDelete;
  final ValueChanged<int>? onExerciseHistory;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final t = context.textStyles;
    final c = context.fitColors;
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Delete session',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : d == null
            ? const Padding(
                padding: AppSpacing.screenPadding,
                child: EmptyState(message: 'This session no longer exists.'),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: [
                  SectionCard(
                    header: CardHeader(
                      title: d.title,
                      subtitle: TextSpan(text: d.when),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatRow(items: d.stats),
                        if (d.hasNewPr) const Text('New PR'),
                        if (d.notes != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(d.notes!, style: t.body),
                        ],
                      ],
                    ),
                  ),
                  for (final e in d.exercises) ...[
                    gap,
                    SectionCard(
                      header: CardHeader(
                        title: e.name,
                        trailing:
                            e.exerciseId == null || onExerciseHistory == null
                            ? null
                            : IconButton(
                                tooltip: 'View exercise history for ${e.name}',
                                onPressed: () =>
                                    onExerciseHistory!(e.exerciseId!),
                                icon: const Icon(Icons.history),
                              ),
                      ),
                      child: e.sets.isEmpty
                          ? Text('No sets logged', style: t.label)
                          : Column(
                              children: [
                                for (final s in e.sets)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.xs,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 56,
                                          child: Text(
                                            'SET ${s.number}',
                                            style: t.overline,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            s.newPr
                                                ? '${s.text} · New PR'
                                                : s.text,
                                            style: s.completed
                                                ? t.bodyStrong
                                                : t.body.copyWith(
                                                    color: c.inkMuted,
                                                  ),
                                          ),
                                        ),
                                        if (!s.completed)
                                          Text('not done', style: t.label),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
