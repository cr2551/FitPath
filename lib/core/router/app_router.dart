import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/nutrition/presentation/custom_food/custom_food_screen.dart';
import '../../features/nutrition/presentation/day_overview/day_overview_screen.dart';
import '../../features/nutrition/presentation/entry/entry_screen.dart';
import '../../features/nutrition/presentation/food_details/food_details_screen.dart';
import '../../features/nutrition/presentation/search/food_search_screen.dart';
import '../../features/onboarding/application/onboarding_status_provider.dart';
import '../../features/onboarding/presentation/estimates_screen.dart';
import '../../features/onboarding/presentation/goal_details_screen.dart';
import '../../features/onboarding/presentation/goals_screen.dart';
import '../../features/onboarding/presentation/setup_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/backup_screen.dart';
import '../../features/settings/presentation/goals_screen.dart';
import '../../features/settings/presentation/profile_edit_screen.dart';
import '../../features/settings/presentation/reset_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/targets_screen.dart';
import '../../features/workouts/presentation/active_session/active_session_screen.dart';
import '../../features/workouts/presentation/custom_exercise/custom_exercise_screen.dart';
import '../../features/workouts/presentation/exercise_picker/exercise_picker_screen.dart';
import '../../features/workouts/presentation/session_detail/session_detail_screen.dart';
import '../../features/workouts/presentation/workouts_screen.dart';
import '../../shared/models/enums.dart';
import '../utils/dates.dart';
import 'app_shell.dart';
import 'placeholder_screen.dart';
import 'routes.dart';

/// The app's router: onboarding outside the shell, and five tabs that each
/// keep their own navigation stack. Detail screens are pushed inside their
/// tab, so the bottom bar stays visible and back returns within the tab.
///
/// FROZEN after #3: features replace their placeholder screen files instead.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect when onboarding completes (or is reset).
  final refresh = ValueNotifier(0);
  ref.listen(onboardingCompletedProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(onboardingCompletedProvider);
      // Still loading the stored flag: stay put; the refresh re-runs this.
      if (done == null) return null;
      final inOnboarding = state.matchedLocation.startsWith('/onboarding');
      if (!done && !inOnboarding) return Routes.welcome;
      if (done && inOnboarding) return Routes.home;
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      _route(Routes.welcome, (_) => const WelcomeScreen()),
      _route(Routes.setup, (_) => const SetupScreen()),
      _route(Routes.onboardingGoals, (_) => const OnboardingGoalsScreen()),
      _route(Routes.goalDetails, (_) => const GoalDetailsScreen()),
      _route(Routes.estimates, (_) => const EstimatesScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [_route(Routes.home, (_) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                Routes.nutrition,
                (s) => DayOverviewScreen(date: _date(s)),
                routes: [
                  _route(
                    'search',
                    (s) => FoodSearchScreen(meal: _meal(s), date: _date(s)),
                  ),
                  _route(
                    'food/:foodId',
                    (s) => _withId(
                      s,
                      'foodId',
                      (id) => FoodDetailsScreen(
                        foodId: id,
                        meal: _meal(s),
                        date: _date(s),
                      ),
                    ),
                  ),
                  _route(
                    'entry/new',
                    (s) => EntryScreen(
                      foodId: _int(s.uri.queryParameters['foodId']),
                      meal: _meal(s),
                      date: _date(s),
                    ),
                  ),
                  _route(
                    'entry/:entryId',
                    (s) =>
                        _withId(s, 'entryId', (id) => EntryScreen(entryId: id)),
                  ),
                  _route('custom-food/new', (_) => const CustomFoodScreen()),
                  _route(
                    'custom-food/:foodId',
                    (s) => _withId(
                      s,
                      'foodId',
                      (id) => CustomFoodScreen(foodId: id),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                Routes.workouts,
                (_) => const WorkoutsScreen(),
                routes: [
                  _route('session', (_) => const ActiveSessionScreen()),
                  _route('exercises/pick', (_) => const ExercisePickerScreen()),
                  _route('exercises/new', (_) => const CustomExerciseScreen()),
                  _route(
                    'exercises/:exerciseId',
                    (s) => _withId(
                      s,
                      'exerciseId',
                      (id) => CustomExerciseScreen(exerciseId: id),
                    ),
                  ),
                  _route(
                    'history/:sessionId',
                    (s) => _withId(
                      s,
                      'sessionId',
                      (id) => SessionDetailScreen(sessionId: id),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [_route(Routes.progress, (_) => const ProgressScreen())],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                Routes.profile,
                (_) => const SettingsScreen(),
                routes: [
                  _route('details', (_) => const ProfileEditScreen()),
                  _route('goals', (_) => const GoalsSettingsScreen()),
                  _route('targets', (_) => const TargetsScreen()),
                  _route('backup', (_) => const BackupScreen()),
                  _route('reset', (_) => const ResetScreen()),
                  _route('about', (_) => const AboutScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

GoRoute _route(
  String path,
  Widget Function(GoRouterState state) build, {
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  builder: (context, state) => build(state),
  routes: routes,
);

/// Builds [screen] for a numeric path parameter, or "not found".
Widget _withId(GoRouterState s, String param, Widget Function(int) screen) {
  final id = _int(s.pathParameters[param]);
  return id == null ? const NotFoundScreen() : screen(id);
}

int? _int(String? v) => v == null ? null : int.tryParse(v);

MealType? _meal(GoRouterState s) =>
    MealType.values.asNameMap()[s.uri.queryParameters['meal']];

DateTime? _date(GoRouterState s) {
  final key = s.uri.queryParameters['date'];
  if (key == null) return null;
  try {
    return Dates.fromLocalDateKey(key);
  } on FormatException {
    if (kDebugMode) debugPrint('Ignoring invalid date "$key" in ${s.uri}');
    return null;
  }
}
