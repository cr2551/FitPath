import '../../../shared/models/enums.dart';

/// What a dashboard card is, for the "Add cards" library and edit mode.
class CardDefinition {
  const CardDefinition({
    required this.type,
    required this.title,
    required this.description,
    this.defaultSize = CardSize.regular,
  });

  final DashboardCardType type;
  final String title;
  final String description;
  final CardSize defaultSize;
}

/// A card in a preset, optionally with extra configuration.
class PresetCard {
  const PresetCard(this.type, {this.config});

  final DashboardCardType type;

  /// Stored as `dashboard_cards.config_json`.
  final String? config;
}

abstract final class CardCatalog {
  static const all = <CardDefinition>[
    CardDefinition(
      type: DashboardCardType.caloriesMacros,
      title: 'Calories & macros',
      description:
          'Calories eaten vs your goal, split by protein, carbs and '
          'fat.',
    ),
    CardDefinition(
      type: DashboardCardType.weightTrend,
      title: 'Weight',
      description: 'Latest weight and the trend over the last 30 days.',
      defaultSize: CardSize.compact,
    ),
    CardDefinition(
      type: DashboardCardType.nutritionSummary,
      title: 'Nutrition summary',
      description: 'Average calories over the last 7 days and days logged.',
      defaultSize: CardSize.compact,
    ),
    CardDefinition(
      type: DashboardCardType.workoutSummary,
      title: 'This week',
      description: 'Training days, sessions, sets and volume this week.',
    ),
    CardDefinition(
      type: DashboardCardType.recentSessions,
      title: 'Recent sessions',
      description: 'Your last completed workouts.',
    ),
    CardDefinition(
      type: DashboardCardType.strengthProgression,
      title: 'Strength progression',
      description: 'Best sets of your top exercises vs the previous session.',
    ),
    CardDefinition(
      type: DashboardCardType.activityOverview,
      title: 'Activity overview',
      description: 'The last 7 days with workouts and food logged.',
      defaultSize: CardSize.compact,
    ),
  ];

  static CardDefinition of(DashboardCardType type) =>
      all.firstWhere((c) => c.type == type);
}

/// Configuration that asks the calories card to emphasise protein.
const proteinEmphasisConfig = '{"emphasis":"protein"}';

/// The initial layout generated from the primary goal (spec section 5).
abstract final class GoalPresets {
  static List<PresetCard> forGoal(GoalType goal) => switch (goal) {
    GoalType.loseWeight => const [
      PresetCard(DashboardCardType.caloriesMacros),
      PresetCard(DashboardCardType.weightTrend),
      PresetCard(DashboardCardType.nutritionSummary),
      PresetCard(DashboardCardType.workoutSummary),
    ],
    GoalType.buildMuscle => const [
      PresetCard(
        DashboardCardType.caloriesMacros,
        config: proteinEmphasisConfig,
      ),
      PresetCard(DashboardCardType.workoutSummary),
      PresetCard(DashboardCardType.strengthProgression),
      PresetCard(DashboardCardType.weightTrend),
    ],
    GoalType.maintainWeight => const [
      PresetCard(DashboardCardType.caloriesMacros),
      PresetCard(DashboardCardType.weightTrend),
      PresetCard(DashboardCardType.workoutSummary),
    ],
    GoalType.improveStrength => const [
      PresetCard(DashboardCardType.workoutSummary),
      PresetCard(DashboardCardType.strengthProgression),
      PresetCard(DashboardCardType.recentSessions),
      PresetCard(DashboardCardType.nutritionSummary),
    ],
    GoalType.generalFitness => const [
      PresetCard(DashboardCardType.workoutSummary),
      PresetCard(DashboardCardType.activityOverview),
      PresetCard(DashboardCardType.nutritionSummary),
      PresetCard(DashboardCardType.weightTrend),
    ],
  };
}
