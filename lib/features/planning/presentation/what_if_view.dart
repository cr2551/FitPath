import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';
import '../../progress/presentation/charts/chart_helpers.dart';
import '../../progress/presentation/weight/weight_chart.dart';
import 'projection_chart.dart';

/// A projection ready to show.
class WhatIfResult {
  const WhatIfResult({
    required this.measured,
    required this.projected,
    required this.target,
    required this.estimatedDate,
    required this.weeklyPace,
    required this.warnings,
    required this.disclaimer,
    required this.explanation,
    required this.notes,
  });

  /// Recent weigh-ins, oldest first, in the display unit.
  final List<ChartPoint> measured;

  /// Today onwards, oldest first, in the display unit.
  final List<ChartPoint> projected;
  final double? target;

  /// "12 Mar 2027", "Not within a year" or "No target set".
  final String estimatedDate;

  /// "−0.5 kg a week".
  final String weeklyPace;

  /// Guardrail warnings (fast pace, below the calorie floor).
  final List<String> warnings;

  /// Shown under the chart: the projection is not a promise.
  final String disclaimer;

  /// How the projection is calculated, for the estimate sheet.
  final String explanation;
  final List<String> notes;
}

class WhatIfViewData {
  const WhatIfViewData({
    required this.initialKcal,
    required this.activity,
    required this.activityOptions,
    required this.initialTarget,
    required this.weightUnit,
    required this.targetRange,
    this.missingDetails,
    this.result,
    this.canApply = false,
    this.saving = false,
  });

  final double? initialKcal;
  final ActivityLevel? activity;
  final List<DropdownOption<ActivityLevel>> activityOptions;

  /// In the display unit.
  final double? initialTarget;
  final String weightUnit;
  final ValueRange targetRange;

  /// What is missing from the profile, e.g. "Add your age and height to see
  /// a projection."; null when nothing is.
  final String? missingDetails;

  /// Null until there is something to project.
  final WhatIfResult? result;
  final bool canApply;
  final bool saving;
}

class WhatIfCallbacks {
  const WhatIfCallbacks({
    required this.onKcal,
    required this.onActivity,
    required this.onTarget,
    required this.onApply,
    required this.onEditDetails,
    required this.onRetry,
  });

  /// Null while empty or invalid.
  final ValueChanged<double?> onKcal;
  final ValueChanged<ActivityLevel> onActivity;

  /// In the display unit; null while empty or invalid.
  final ValueChanged<double?> onTarget;
  final VoidCallback onApply;
  final VoidCallback onEditDetails;
  final VoidCallback onRetry;
}

/// Allowed daily intake on the what-if screen.
const whatIfKcalRange = ValueRange(800, 6000);

/// Pure layout for the what-if calculator.
class WhatIfView extends StatelessWidget {
  const WhatIfView({
    super.key,
    required this.data,
    required this.callbacks,
    this.error,
  });

  /// Null while loading.
  final WhatIfViewData? data;
  final String? error;
  final WhatIfCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: const Text('What if')),
      body: SafeArea(
        child: error != null
            ? Padding(
                padding: AppSpacing.screenPadding,
                child: ErrorState(message: error!, onRetry: callbacks.onRetry),
              )
            : d == null
            ? const Center(child: CircularProgressIndicator())
            : _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, WhatIfViewData d) {
    final t = context.textStyles;
    final cb = callbacks;
    const gap = SizedBox(height: AppSpacing.md);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'See where a daily intake would take your weight.',
          style: t.label,
        ),
        gap,
        UnitNumberField(
          label: 'Daily calories',
          unit: 'kcal',
          range: whatIfKcalRange,
          decimals: 0,
          initialValue: d.initialKcal,
          onChanged: cb.onKcal,
        ),
        gap,
        AppDropdown<ActivityLevel>(
          label: 'Activity level',
          value: d.activity,
          options: d.activityOptions,
          onChanged: cb.onActivity,
        ),
        gap,
        UnitNumberField(
          label: 'Target weight',
          unit: d.weightUnit,
          range: d.targetRange,
          isRequired: false,
          initialValue: d.initialTarget,
          onChanged: cb.onTarget,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (d.missingDetails != null)
          SectionCard(
            header: const CardHeader(title: 'Projected weight'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(d.missingDetails!, style: t.body),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: cb.onEditDetails,
                  child: const Text('COMPLETE YOUR DETAILS'),
                ),
              ],
            ),
          )
        else if (d.result == null)
          const SectionCard(
            header: CardHeader(title: 'Projected weight'),
            child: EmptyChart(
              message: 'Enter daily calories to see a projection.',
            ),
          )
        else
          _ResultCard(result: d.result!),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          style: AppTheme.accentButton(context),
          onPressed: d.canApply && !d.saving ? cb.onApply : null,
          child: const Text('APPLY AS MY TARGETS'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Applying sets this intake as your calorie target from today. Past '
          'days keep the targets that applied then.',
          style: t.label,
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final WhatIfResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    final r = result;
    return SectionCard(
      header: CardHeader(
        title: 'Projected weight',
        trailing: EstimateBadge(
          onTap: () => showEstimateSheet(
            context,
            title: 'How the projection works',
            explanation: r.explanation,
            notes: r.notes,
          ),
        ),
      ),
      footer: StatRow(
        items: [
          StatItem(label: 'Estimated date', value: r.estimatedDate),
          StatItem(label: 'Weekly pace', value: r.weeklyPace),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                'Projected weight from ${ChartAxes.valueLabel(r.projected.first.value)} '
                'to ${ChartAxes.valueLabel(r.projected.last.value)}',
            child: ExcludeSemantics(
              child: ProjectionChart(
                measured: r.measured,
                projected: r.projected,
                target: r.target,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChartLegend(
            items: [
              if (r.measured.isNotEmpty)
                const LegendItem('Measured', SeriesStyle.measured),
              LegendItem('Projected', SeriesStyle.estimate, color: c.accent),
              if (r.target != null)
                const LegendItem('Target', SeriesStyle.target),
            ],
          ),
          for (final w in r.warnings) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, size: 18, color: c.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(w, style: t.label.copyWith(color: c.ink)),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(r.disclaimer, style: t.label),
        ],
      ),
    );
  }
}
