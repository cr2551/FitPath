import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/widgets/widgets.dart';
import 'charts/chart_helpers.dart';

enum ProgressTab { weight, nutrition, workouts }

/// Pure layout for the Progress tab: the dataset control, the shared range
/// buttons and the selected tab's body.
class ProgressView extends StatelessWidget {
  const ProgressView({
    super.key,
    required this.tab,
    required this.range,
    required this.body,
    required this.onTabChanged,
    required this.onRangeChanged,
  });

  final ProgressTab tab;
  final RangePreset range;
  final Widget body;
  final ValueChanged<ProgressTab> onTabChanged;
  final ValueChanged<RangePreset> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            const ScreenHeader(title: 'Progress'),
            SegmentedButton<ProgressTab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ProgressTab.weight, label: Text('WEIGHT')),
                ButtonSegment(
                  value: ProgressTab.nutrition,
                  label: Text('NUTRITION'),
                ),
                ButtonSegment(
                  value: ProgressTab.workouts,
                  label: Text('WORKOUTS'),
                ),
              ],
              selected: {tab},
              onSelectionChanged: (s) => onTabChanged(s.single),
            ),
            const SizedBox(height: AppSpacing.md),
            _RangeButtons(selected: range, onChanged: onRangeChanged),
            const SizedBox(height: AppSpacing.md),
            body,
          ],
        ),
      ),
    );
  }
}

class _RangeButtons extends StatelessWidget {
  const _RangeButtons({required this.selected, required this.onChanged});

  final RangePreset selected;
  final ValueChanged<RangePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return Row(
      children: [
        for (final r in RangePreset.values) ...[
          if (r != RangePreset.values.first)
            const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Semantics(
              button: true,
              selected: r == selected,
              child: Material(
                color: c.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.smAll,
                  side: BorderSide(color: r == selected ? c.ink : c.line),
                ),
                child: InkWell(
                  borderRadius: AppRadii.smAll,
                  onTap: () => onChanged(r),
                  child: Container(
                    // A 48 dp tap target (Android accessibility guideline).
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: r == selected
                        ? BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: c.ink, width: 2),
                            ),
                          )
                        : null,
                    child: Text(
                      ChartAxes.rangeLabel(r),
                      style: t.overline.copyWith(
                        fontSize: 14,
                        color: r == selected ? c.ink : c.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
