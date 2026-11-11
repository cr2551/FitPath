import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/fit_colors.dart';
import '../../core/utils/dates.dart';

/// A row of day tiles (usually one week). The selected day is an ink tile
/// with white text; a small square marker means the day has entries, and an
/// accent bar under the date marks today.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.daysWithEntries = const {},
    this.today,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Local date keys (yyyy-MM-dd) of days that have entries.
  final Set<String> daysWithEntries;

  /// Days before this are shown muted. Defaults to now.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = Dates.startOfDay(today ?? DateTime.now());
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: _DayTile(
              day: days[i],
              selected: Dates.isSameDay(days[i], selected),
              past: Dates.startOfDay(days[i]).isBefore(now),
              isToday: Dates.isSameDay(days[i], now),
              hasEntries: daysWithEntries.contains(Dates.localDateKey(days[i])),
              onTap: () => onSelected(Dates.startOfDay(days[i])),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.selected,
    required this.past,
    required this.isToday,
    required this.hasEntries,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool past;
  final bool isToday;
  final bool hasEntries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final fg = selected ? c.surface : (past ? c.inkMuted : c.ink);
    final marker = selected ? c.surface : c.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${DateFormat('EEEE d MMMM').format(day)}'
          '${isToday ? ', today' : ''}'
          '${hasEntries ? ', has entries' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? c.ink : c.subtle,
        borderRadius: AppRadii.mdAll,
        child: InkWell(
          borderRadius: AppRadii.mdAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: t.overline.copyWith(
                      color: selected ? c.surface : c.inkMuted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox.square(
                      dimension: 4,
                      child: ColoredBox(
                        color: hasEntries ? marker : Colors.transparent,
                      ),
                    ),
                  ),
                  Text(
                    day.day.toString().padLeft(2, '0'),
                    style: t.cardTitle.copyWith(fontSize: 19, color: fg),
                  ),
                  // Today marker: an accent bar under the date, kept (as
                  // transparent) on other days so every tile is the same height.
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SizedBox(
                      width: 14,
                      height: 3,
                      child: ColoredBox(
                        color: isToday ? c.accent : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
