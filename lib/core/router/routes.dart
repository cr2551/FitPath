import '../../shared/models/enums.dart';
import '../utils/dates.dart';

/// Every MVP route. Navigate with these, never with string literals:
/// `context.go(Routes.nutrition)`, `context.push(Routes.foodDetails(id))`.
///
/// FROZEN after #3: screens are added by replacing their placeholder file,
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

  // Workouts.
  static const activeSession = '$workouts/session';
  static const exercisePicker = '$workouts/exercises/pick';
  static const newCustomExercise = '$workouts/exercises/new';
  static String editCustomExercise(int exerciseId) =>
      '$workouts/exercises/$exerciseId';
  static String sessionDetail(int sessionId) => '$workouts/history/$sessionId';

  // Profile & Settings.
  static const profileDetails = '$profile/details';
  static const goals = '$profile/goals';
  static const targets = '$profile/targets';
  static const backup = '$profile/backup';
  static const reset = '$profile/reset';
  static const about = '$profile/about';

  static Map<String, String> _mealDate(MealType? meal, DateTime? date) => {
    'meal': ?meal?.name,
    if (date != null) 'date': Dates.localDateKey(date),
  };

  static String _with(String path, Map<String, String> query) =>
      query.isEmpty ? path : Uri(path: path, queryParameters: query).toString();
}
