import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../nutrition/application/diary_providers.dart';
import '../../../nutrition/domain/nutrition_math.dart';
import '../../../profile/application/profile_providers.dart';
import 'nutrition_summary_card_view.dart';

/// Home nutrition summary: average calories over the last 7 days (days
/// with entries only) against today's target, and how many days were
/// logged.
class NutritionSummaryCard extends ConsumerWidget {
  const NutritionSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(dailyTotalsProvider(RangePreset.days7));
    final target = ref.watch(currentTargetsProvider);

    if (totals.hasError || target.hasError) {
      return SectionCard(
        child: ErrorState(
          message: "Couldn't load your nutrition.",
          onRetry: () => ref.invalidate(dailyTotalsProvider(RangePreset.days7)),
        ),
      );
    }
    if (!totals.hasValue || !target.hasValue) {
      return const SectionCard(
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return NutritionSummaryCardView(
      data: nutritionSummaryViewData(
        totals.requireValue,
        target.requireValue?.calories,
      ),
      onTap: () => context.go(Routes.nutrition),
    );
  }
}

/// Maps the last 7 days of daily totals (keyed by date, logged days only).
NutritionSummaryViewData nutritionSummaryViewData(
  Map<String, NutrientTotals> byDay,
  int? targetKcal,
) {
  final logged = byDay.values.where((t) => !t.isEmpty).toList();
  final average = logged.isEmpty
      ? null
      : logged.fold<double>(0, (sum, t) => sum + t.kcal) / logged.length;
  return NutritionSummaryViewData(
    averageKcal: average == null ? null : Formatters.integer(average),
    targetKcal: Formatters.integer(targetKcal),
    daysLogged: '${logged.length} of 7',
    overTarget:
        average != null &&
        targetKcal != null &&
        targetKcal > 0 &&
        average > targetKcal,
  );
}
