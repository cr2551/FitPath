import 'package:flutter/material.dart';

import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class PrCardRow {
  const PrCardRow({
    required this.exerciseId,
    required this.exercise,
    required this.record,
    required this.date,
  });

  final int exerciseId;
  final String exercise;

  /// E.g. "Heaviest load · 100 kg".
  final String record;

  /// E.g. "10 Nov".
  final String date;
}

/// Pure layout for the "Personal records" card.
class PersonalRecordsCardView extends StatelessWidget {
  const PersonalRecordsCardView({
    super.key,
    required this.rows,
    required this.onExercise,
  });

  /// Newest first; empty before the first record.
  final List<PrCardRow> rows;
  final ValueChanged<int> onExercise;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      header: const CardHeader(
        title: 'Personal records',
        icon: Icons.emoji_events_outlined,
      ),
      child: rows.isEmpty
          ? Text(
              'No personal records yet. Beat a best set from an earlier '
              'workout to set one.',
              style: context.textStyles.label,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListRow(
                    title: rows[i].exercise,
                    subtitle: '${rows[i].record} · ${rows[i].date}',
                    onTap: () => onExercise(rows[i].exerciseId),
                  ),
                ],
              ],
            ),
    );
  }
}
