import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';

/// One figure of the week next to last week's.
class ReportFigure {
  const ReportFigure({
    required this.label,
    required this.value,
    required this.previous,
    this.unit,
  });

  final String label;

  /// E.g. "2,050", or "Not logged" when missing.
  final String value;
  final String? unit;

  /// E.g. "Last week 1,900 (+150)" or "Last week not logged".
  final String previous;
}

class ReportPrRow {
  const ReportPrRow({
    required this.exerciseId,
    required this.exercise,
    required this.record,
    required this.date,
  });

  final int exerciseId;
  final String exercise;

  /// E.g. "Heaviest load · 100 kg".
  final String record;

  /// E.g. "Tue 10 Nov".
  final String date;
}

class WeeklyReportViewData {
  const WeeklyReportViewData({
    required this.weekLabel,
    required this.canGoNext,
    required this.isEmpty,
    this.nutrition = const [],
    this.training = const [],
    this.weight = const [],
    this.prs = const [],
  });

  /// E.g. "8 – 14 Nov 2026".
  final String weekLabel;

  /// False on the current week.
  final bool canGoNext;

  /// Nothing logged in the week.
  final bool isEmpty;
  final List<ReportFigure> nutrition;
  final List<ReportFigure> training;
  final List<ReportFigure> weight;
  final List<ReportPrRow> prs;
}

class WeeklyReportCallbacks {
  const WeeklyReportCallbacks({
    required this.onPrevious,
    required this.onNext,
    required this.onExercise,
    required this.onRetry,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onExercise;
  final VoidCallback onRetry;
}

/// Pure layout for the weekly report: week picker, then nutrition, training
/// and weight, each compared with the week before.
class WeeklyReportView extends StatelessWidget {
  const WeeklyReportView({
    super.key,
    required this.weekLabel,
    required this.data,
    required this.callbacks,
    this.error,
  });

  /// Shown while loading too.
  final String weekLabel;

  /// Null while loading.
  final WeeklyReportViewData? data;
  final String? error;
  final WeeklyReportCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final d = data;
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly report')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            _WeekPicker(
              label: d?.weekLabel ?? weekLabel,
              canGoNext: d?.canGoNext ?? false,
              onPrevious: callbacks.onPrevious,
              onNext: callbacks.onNext,
            ),
            gap,
            if (error != null)
              ErrorState(message: error!, onRetry: callbacks.onRetry)
            else if (d == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (d.isEmpty)
              const SectionCard(
                child: EmptyState(
                  message:
                      'Nothing logged this week: no food, workouts or '
                      'weight.',
                ),
              )
            else ...[
              _Section(
                title: 'Nutrition',
                figures: d.nutrition,
                note: 'Averages over the days you logged food.',
              ),
              gap,
              _Section(
                title: 'Training',
                figures: d.training,
                extra: d.prs.isEmpty
                    ? null
                    : _PrList(prs: d.prs, onExercise: callbacks.onExercise),
              ),
              gap,
              _Section(title: 'Weight', figures: d.weight),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.label,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            style: context.textStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.figures,
    this.note,
    this.extra,
  });

  final String title;
  final List<ReportFigure> figures;
  final String? note;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return SectionCard(
      header: CardHeader(title: title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < figures.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _FigureRow(figure: figures[i]),
          ],
          if (extra != null) ...[const Divider(height: 1), extra!],
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(note!, style: t.label),
          ],
        ],
      ),
    );
  }
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.figure});

  final ReportFigure figure;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final value = Text.rich(
      TextSpan(
        text: figure.value,
        style: t.bodyStrong,
        children: [
          if (figure.unit != null)
            TextSpan(text: ' ${figure.unit}', style: t.label),
        ],
      ),
      textAlign: TextAlign.end,
    );
    return Semantics(
      container: true,
      label:
          '${figure.label} ${figure.value} ${figure.unit ?? ''}. '
          '${figure.previous}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(figure.label, style: t.body)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  value,
                  Text(
                    figure.previous,
                    style: t.label,
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrList extends StatelessWidget {
  const _PrList({required this.prs, required this.onExercise});

  final List<ReportPrRow> prs;
  final ValueChanged<int> onExercise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text('NEW PERSONAL RECORDS', style: context.textStyles.overline),
        for (final pr in prs)
          ListRow(
            title: pr.exercise,
            subtitle: '${pr.record} · ${pr.date}',
            onTap: () => onExercise(pr.exerciseId),
          ),
      ],
    );
  }
}
