import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/models/enums.dart';
import 'cards/activity_overview_card.dart';
import 'cards/calories_macros_card.dart';
import 'cards/nutrition_summary_card.dart';
import 'cards/recent_sessions_card.dart';
import 'cards/strength_progression_card.dart';
import 'cards/weight_trend_card.dart';
import 'cards/workout_summary_card.dart';

/// Maps each dashboard card type to its container widget. A card container
/// reads its own data (and the Home selected date when it needs one).
abstract final class CardRegistry {
  static Widget build(DashboardCard card) => switch (card.cardType) {
    DashboardCardType.caloriesMacros => const CaloriesMacrosCard(),
    DashboardCardType.weightTrend => const WeightTrendCard(),
    DashboardCardType.nutritionSummary => const NutritionSummaryCard(),
    DashboardCardType.workoutSummary => const WorkoutSummaryCard(),
    DashboardCardType.recentSessions => const RecentSessionsCard(),
    DashboardCardType.strengthProgression => const StrengthProgressionCard(),
    DashboardCardType.activityOverview => const ActivityOverviewCard(),
  };
}
