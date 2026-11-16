import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../progress/domain/weekly_report.dart';
import '../../../reports/application/weekly_report_providers.dart';
import '../../../reports/presentation/weekly_report_screen.dart' show weekLabel;
import 'card_loading.dart';
import 'weekly_report_card_view.dart';

/// Home "Last week's report": the last full week's headline figures vs the
/// week before. Tapping opens the weekly report.
class WeeklyReportCard extends ConsumerWidget {
  const WeeklyReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(reportSourcesProvider);
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    if (sources.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load last week's report.",
          onRetry: () => retryReportSources(ref),
        ),
      );
    }
    if (!sources.hasValue) return const CardLoading();
    return WeeklyReportCardView(
      data: weeklyReportCardData(sources.requireValue, DateTime.now(), units),
      onTap: () => context.push(Routes.weeklyReport()),
    );
  }
}

/// Last full week before [now] against the week before it.
WeeklyReportCardData weeklyReportCardData(
  ReportSources sources,
  DateTime now,
  UnitSystem units,
) {
  final lastWeek = Dates.addDays(Dates.startOfWeek(now), -7);
  final (:report, prs: _) = buildWeeklyReport(sources, lastWeek);
  final w = report.week, p = report.previous;
  final label = weekLabel(lastWeek, now);
  if (w.nutrition.daysLogged == 0 &&
      w.training.sessions == 0 &&
      w.weight.lastKg.isMissing) {
    return WeeklyReportCardData(week: label, stats: const [], previous: null);
  }

  final unit = Units.weightUnit(units);
  String kcal(Figure f) => Formatters.integer(f.value);
  String change(Figure f) {
    final v = f.value;
    if (v == null) return Formatters.unknownValue;
    final shown = Units.weightForDisplay(v.abs(), units).toStringAsFixed(1);
    return shown == '0.0' ? '0' : '${v > 0 ? '+' : '−'}$shown';
  }

  final before = [
    p.nutrition.averageKcal.isMissing
        ? 'food not logged'
        : '${kcal(p.nutrition.averageKcal)} kcal',
    '${p.training.sessions} '
        '${p.training.sessions == 1 ? 'workout' : 'workouts'}',
    p.weight.changeKg.isMissing
        ? 'no weight change'
        : '${change(p.weight.changeKg)} $unit',
  ];
  return WeeklyReportCardData(
    week: label,
    stats: [
      StatItem(
        label: 'Avg intake',
        value: kcal(w.nutrition.averageKcal),
        unit: w.nutrition.averageKcal.isMissing ? null : 'kcal',
      ),
      StatItem(label: 'Workouts', value: '${w.training.sessions}'),
      StatItem(
        label: 'Weight',
        value: change(w.weight.changeKg),
        unit: w.weight.changeKg.isMissing ? null : unit,
      ),
    ],
    previous: 'Week before: ${before.join(' · ')}',
  );
}
