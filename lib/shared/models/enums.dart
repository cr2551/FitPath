/// Domain enums shared across features and the database schema.
///
/// They are persisted by name (Drift `textEnum`), so renaming a value is a
/// schema change that needs a migration. Appending new values is safe.
library;

/// Measurement system used for display and input. Values are always stored in
/// canonical metric units (kg, cm, g, ml).
enum UnitSystem { metric, imperial }

/// Optional sex input used only for metabolic estimates (BMR).
enum Sex { male, female, unspecified }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum GoalType {
  loseWeight,
  buildMuscle,
  maintainWeight,
  improveStrength,
  generalFitness,
}

enum TrainingExperience { beginner, intermediate, advanced }

enum MealType { breakfast, lunch, dinner, snack }

/// The amount a food's nutrient values refer to. Grams and millilitres are
/// never treated as interchangeable.
enum ReferenceBasis { per100g, per100ml, perServing }

/// [recipe] is a food row built from a recipe's ingredients (Phase 2).
enum FoodSource { bundled, openFoodFacts, custom, recipe }

/// Only [completed] sessions count toward summaries and history.
enum WorkoutStatus { inProgress, completed, discarded }

enum DashboardCardType {
  caloriesMacros,
  weightTrend,
  nutritionSummary,
  workoutSummary,
  recentSessions,
  strengthProgression,
  activityOverview,
  personalRecords,
  streak,
  weeklyReport,
}

enum CardSize { compact, regular }

/// Whether a nutrition target was suggested by the app or set by the user.
enum TargetSource { calculated, user }
