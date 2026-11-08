import '../../shared/models/enums.dart';
import '../utils/dates.dart';

/// Every MVP and Phase 2 route. Navigate with these, never with string literals:
/// `context.go(Routes.nutrition)`, `context.push(Routes.foodDetails(id))`.
///
/// FROZEN after #3 and again after #103 (Phase 2): screens are added by replacing their placeholder file,
/// not by editing this table.
abstract final class Routes {
  // Onboarding (outside the bottom navigation).
  static const welcome = '/onboarding/welcome';
  static const setup = '/onboarding/setup';
  static const onboardingGoals = '/onboarding/goals';
  static const goalDetails = '/onboarding/goal-details';
  static const estimates = '/onboarding/estimates';

  // Tabs.
  static const home = '/';
  static const nutrition = '/nutrition';
  static const workouts = '/workouts';
  static const progress = '/progress';
  static const profile = '/profile';

  // Nutrition.
  static String nutritionDay(DateTime day) =>
      _with(nutrition, {'date': Dates.localDateKey(day)});
  static String foodSearch({MealType? meal, DateTime? date}) =>
      _with('$nutrition/search', _mealDate(meal, date));
  static String foodDetails(int foodId, {MealType? meal, DateTime? date}) =>
      _with('$nutrition/food/$foodId', _mealDate(meal, date));

  /// [quantity] and [unit] ('g', 'ml' or 'serving') prefill the amount,
  /// e.g. what the user already typed on the food details screen.
  static String newEntry({
    required int foodId,
    MealType? meal,
    DateTime? date,
    double? quantity,
    String? unit,
  }) => _with('$nutrition/entry/new', {
    'foodId': '$foodId',
    ..._mealDate(meal, date),
    if (quantity != null) 'quantity': '$quantity',
    'unit': ?unit,
  });
  static String editEntry(int entryId) => '$nutrition/entry/$entryId';
  static const newCustomFood = '$nutrition/custom-food/new';
  static String editCustomFood(int foodId) => '$nutrition/custom-food/$foodId';
  static const newRecipe = '$nutrition/recipe/new';
  static String editRecipe(int foodId) => '$nutrition/recipe/$foodId';
  static String recipeIdeas({MealType? meal, DateTime? date}) =>
      _with('$nutrition/recipe-ideas', _mealDate(meal, date));

  // Workouts.
  static const activeSession = '$workouts/session';
  static const exercisePicker = '$workouts/exercises/pick';
  static const newCustomExercise = '$workouts/exercises/new';
  static String editCustomExercise(int exerciseId) =>
      '$workouts/exercises/$exerciseId';
  static String sessionDetail(int sessionId) => '$workouts/history/$sessionId';
  static String exerciseHistory(int exerciseId) =>
      '$workouts/exercise-history/$exerciseId';

  // Progress.
  /// [weekStart] is any day of the week to show; without it, last week.
  static String weeklyReport({DateTime? weekStart}) => _with(
    '$progress/weekly-report',
    {if (weekStart != null) 'week': Dates.localDateKey(weekStart)},
  );

  // Profile & Settings.
  static const profileDetails = '$profile/details';
  static const goals = '$profile/goals';
  static const targets = '$profile/targets';
  static const backup = '$profile/backup';
  static const reset = '$profile/reset';
  static const about = '$profile/about';
  static const whatIf = '$profile/what-if';

  static Map<String, String> _mealDate(MealType? meal, DateTime? date) => {
    'meal': ?meal?.name,
    if (date != null) 'date': Dates.localDateKey(date),
  };

  static String _with(String path, Map<String, String> query) =>
      query.isEmpty ? path : Uri(path: path, queryParameters: query).toString();
}
