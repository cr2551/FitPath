import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../profile/application/profile_providers.dart';
import '../../progress/domain/weekly_report.dart';
import '../../workouts/domain/strength_stats.dart';
import '../application/weekly_report_providers.dart';
import 'weekly_report_view.dart';

/// The report for one Sunday-Saturday week, compared with the week before.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  const WeeklyReportScreen({super.key, this.weekStart});

  /// Any day of the week to show; null means last week.
  final DateTime? weekStart;

  @override
  ConsumerState<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  late DateTime _week = Dates.startOfWeek(
    widget.weekStart ?? Dates.addDays(DateTime.now(), -7),
  );

  void _move(int weeks) =>
      setState(() => _week = Dates.addDays(_week, 7 * weeks));

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(reportSourcesProvider);
    final units = ref.watch(unitSystemProvider).value ?? UnitSystem.metric;
    final now = DateTime.now();
    return WeeklyReportView(
      weekLabel: weekLabel(_week, now),
      data: sources.hasValue
          ? weeklyReportViewData(sources.requireValue, _week, now, units)
          : null,
      error: sources.hasError ? "Couldn't load your weekly report." : null,
      callbacks: WeeklyReportCallbacks(
        onPrevious: () => _move(-1),
        onNext: () => _move(1),
        onExercise: (id) => context.push(Routes.exerciseHistory(id)),
        onRetry: () => retryReportSources(ref),
      ),
    );
  }
}

/// "8 – 14 Nov 2026", "29 Nov – 5 Dec 2026", with "(so far)" for the
/// current week.
String weekLabel(DateTime weekStart, DateTime now) {
  final start = Dates.startOfWeek(weekStart);
  final end = Dates.addDays(start, 6);
  final first = start.year != end.year
      ? DateFormat('d MMM y').format(start)
      : start.month != end.month
      ? DateFormat('d MMM').format(start)
      : DateFormat('d').format(start);
  final label = '$first – ${DateFormat('d MMM y').format(end)}';
  return Dates.isSameDay(start, Dates.startOfWeek(now))
      ? '$label (so far)'
      : label;
}

/// Maps the history to the report of the week containing [day].
WeeklyReportViewData weeklyReportViewData(
  ReportSources sources,
  DateTime day,
  DateTime now,
  UnitSystem units,
) {
  final (:report, :prs) = buildWeeklyReport(sources, day);
  final w = report.week, p = report.previous;
  final canGoNext = w.weekStart.isBefore(Dates.startOfWeek(now));
  final label = weekLabel(w.weekStart, now);
  if (w.nutrition.daysLogged == 0 &&
      w.training.sessions == 0 &&
      w.weight.lastKg.isMissing) {
    return WeeklyReportViewData(
      weekLabel: label,
      canGoNext: canGoNext,
      isEmpty: true,
    );
  }

  final unit = Units.weightUnit(units);
  String kg(double v) => _decimal(Units.weightForDisplay(v, units));
  String percent(double v) => '${(v * 100).round()}%';

  return WeeklyReportViewData(
    weekLabel: label,
    canGoNext: canGoNext,
    isEmpty: false,
    nutrition: [
      _figure(
        'Average intake',
        w.nutrition.averageKcal,
        p.nutrition.averageKcal,
        Formatters.integer,
        unit: 'kcal',
      ),
      _figure(
        'Average target',
        w.nutrition.averageTargetKcal,
        p.nutrition.averageTargetKcal,
        Formatters.integer,
        unit: 'kcal',
      ),
      ReportFigure(
        label: 'Days logged',
        value: '${w.nutrition.daysLogged} of 7',
        previous: 'Last week ${p.nutrition.daysLogged} of 7',
      ),
      _figure(
        'Protein vs target',
        w.nutrition.proteinAdherence,
        p.nutrition.proteinAdherence,
        percent,
        delta: (v) => '${(v * 100).round()} pts',
      ),
      _figure(
        'Carbs vs target',
        w.nutrition.carbsAdherence,
        p.nutrition.carbsAdherence,
        percent,
        delta: (v) => '${(v * 100).round()} pts',
      ),
      _figure(
        'Fat vs target',
        w.nutrition.fatAdherence,
        p.nutrition.fatAdherence,
        percent,
        delta: (v) => '${(v * 100).round()} pts',
      ),
    ],
    training: [
      _figure(
        'Workouts',
        Figure(w.training.sessions.toDouble()),
        Figure(p.training.sessions.toDouble()),
        Formatters.integer,
      ),
      _figure(
        'Volume',
        Figure(w.training.volumeKg),
        Figure(p.training.volumeKg),
        (v) => Formatters.integer(Units.weightForDisplay(v, units)),
        unit: unit,
      ),
      _figure(
        'New personal records',
        Figure(w.training.newPrs.toDouble()),
        Figure(p.training.newPrs.toDouble()),
        Formatters.integer,
      ),
    ],
    weight: [
      _figure(
        'Last weigh-in',
        w.weight.lastKg,
        p.weight.lastKg,
        kg,
        unit: unit,
      ),
      _figure(
        'Change over the week',
        w.weight.changeKg,
        p.weight.changeKg,
        (v) => _signed(v, kg),
        unit: unit,
        withDelta: false,
      ),
    ],
    prs: [
      for (final r in prs)
        ReportPrRow(
          exerciseId: r.pr.exerciseId,
          exercise: r.exerciseName,
          record: _record(r.pr, kg, unit),
          date: DateFormat('EEE d MMM').format(r.pr.set.date.toLocal()),
        ),
    ],
  );
}

/// [current] against [previous]; missing values say why, never "0".
ReportFigure _figure(
  String label,
  Figure current,
  Figure previous,
  String Function(double) format, {
  String? unit,
  String Function(double)? delta,
  bool withDelta = true,
}) {
  final cur = current.value, prev = previous.value;
  final change = current.changeFrom(previous);
  final String last;
  if (prev == null) {
    last = 'Last week: ${_gap(previous.gap!).toLowerCase()}';
  } else {
    final shown = '${format(prev)}${unit == null ? '' : ' $unit'}';
    final diff = !withDelta || change == null
        ? ''
        : ' (${_signed(change, delta ?? format)})';
    last = 'Last week $shown$diff';
  }
  return ReportFigure(
    label: label,
    value: cur == null ? _gap(current.gap!) : format(cur),
    unit: cur == null ? null : unit,
    previous: last,
  );
}

String _gap(ReportGap gap) => switch (gap) {
  ReportGap.noFoodLogged || ReportGap.noWeightThisWeek => 'Not logged',
  ReportGap.noTarget => 'No target set',
  ReportGap.noEarlierWeight => 'No earlier weight',
};

/// "+150", "−0.4", or unsigned when it rounds to zero.
String _signed(double v, String Function(double) format) {
  final abs = format(v.abs());
  if (abs == format(0)) return abs;
  return '${v > 0 ? '+' : '−'}$abs';
}

/// One decimal, without a trailing ".0".
String _decimal(double v) =>
    v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

String _record(NewPr pr, String Function(double) kg, String unit) {
  final s = pr.set;
  return switch (pr.kind) {
    PrKind.heaviestLoad => 'Heaviest load · ${kg(s.weightKg!)} $unit',
    PrKind.repsAtLoad => '${s.reps} reps at ${kg(s.weightKg!)} $unit',
    PrKind.setVolume => 'Best set volume · ${kg(s.volumeKg!)} $unit',
    PrKind.oneRepMax => 'Estimated 1RM · ${kg(s.oneRepMax!.epleyKg)} $unit',
    PrKind.mostReps => 'Most reps · ${s.reps}',
  };
}
