import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class StreakCardData {
  const StreakCardData({
    required this.current,
    required this.longest,
    required this.thisWeek,
    required this.thisWeekDone,
  });

  final int current;
  final int longest;

  /// This week's status in words.
  final String thisWeek;
  final bool thisWeekDone;
}

/// Pure layout for the "Streak" card.
class StreakCardView extends StatelessWidget {
  const StreakCardView({super.key, required this.data, required this.onTap});

  /// Null before the first completed workout.
  final StreakCardData? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final d = data;
    String weeks(int n) => n == 1 ? 'week' : 'weeks';
    return SectionCard(
      onTap: onTap,
      header: const CardHeader(title: 'Streak', icon: Icons.event_repeat),
      footer: d == null
          ? null
          : StatRow(
              items: [
                StatItem(
                  label: 'Current',
                  value: '${d.current}',
                  unit: weeks(d.current),
                ),
                StatItem(
                  label: 'Longest',
                  value: '${d.longest}',
                  unit: weeks(d.longest),
                ),
              ],
            ),
      child: d == null
          ? Text(
              'No workouts yet. A week counts when it has at least one '
              'workout.',
              style: t.label,
            )
          : Row(
              children: [
                Icon(
                  d.thisWeekDone
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: d.thisWeekDone ? c.ink : c.inkMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(d.thisWeek, style: t.label)),
              ],
            ),
    );
  }
}
