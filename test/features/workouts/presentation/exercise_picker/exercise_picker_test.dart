import 'package:drift/drift.dart' show Value;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/router/routes.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/workouts/presentation/custom_exercise/custom_exercise_screen.dart';
import 'package:fitpath/features/workouts/presentation/exercise_picker/exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// A host page with a button that opens the picker and shows its result.
Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Host()),
      GoRoute(
        path: Routes.exercisePicker,
        builder: (_, _) => const ExercisePickerScreen(),
      ),
      GoRoute(
        path: Routes.newCustomExercise,
        builder: (_, _) => const CustomExerciseScreen(),
      ),
      GoRoute(
        path: '/workouts/exercises/:id',
        builder: (_, s) => CustomExerciseScreen(
          exerciseId: int.parse(s.pathParameters['id']!),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int? _picked;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () async {
            final id = await context.push<int>(Routes.exercisePicker);
            setState(() => _picked = id);
          },
          child: const Text('open picker'),
        ),
        Text('picked $_picked'),
      ],
    ),
  );
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

Future<Map<String, int>> _seed(AppDatabase db) async {
  Future<int> add(String name, String group, {bool custom = false}) =>
      db.workoutDao.insertExercise(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: group,
          equipment: const Value('barbell'),
          isCustom: Value(custom),
        ),
      );
  return {
    'bench': await add('Bench press', 'chest'),
    'squat': await add('Squat', 'legs'),
    'fly': await add('Cable fly', 'chest', custom: true),
  };
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('open picker'));
  await tester.pumpAndSettle();
  await _settle(tester);
}

void main() {
  testWidgets('search, filter chips and custom marker', (tester) async {
    final db = createTestDatabase();
    await tester.runAsync(() => _seed(db));
    await _pump(tester, db);
    await _openPicker(tester);

    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Chest · barbell · Custom'), findsOneWidget);

    await tester.tap(find.text('Legs'));
    await _settle(tester);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Bench press'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), 'BEN');
    await _settle(tester);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await _settle(tester);
    expect(find.text('No exercises match.'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('picking returns the exercise id', (tester) async {
    final db = createTestDatabase();
    final ids = (await tester.runAsync(() => _seed(db)))!;
    await _pump(tester, db);
    await _openPicker(tester);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    expect(find.text('picked ${ids['squat']}'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('create a custom exercise and pick it', (tester) async {
    final db = createTestDatabase();
    await _pump(tester, db);
    await _openPicker(tester);

    await tester.tap(find.byTooltip('Create custom exercise'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'SAVE');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Sissy squat',
    );
    await tester.tap(find.text('Muscle group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bodyweight exercise'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    await _settle(tester);

    final rows = await tester.runAsync(() => db.select(db.exercises).get());
    final created = rows!.single;
    expect(created.name, 'Sissy squat');
    expect(created.muscleGroup, 'legs');
    expect(created.isBodyweight, isTrue);
    expect(created.isCustom, isTrue);
    expect(find.text('picked ${created.id}'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('edit and soft-delete a custom exercise', (tester) async {
    final db = createTestDatabase();
    final ids = (await tester.runAsync(() => _seed(db)))!;
    await _pump(tester, db);
    await _openPicker(tester);

    await tester.tap(find.byTooltip('Edit Cable fly'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('Edit exercise'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Pec fly',
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('Pec fly'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Pec fly'));
    await tester.pumpAndSettle();
    await _settle(tester);
    await tester.tap(find.text('Delete exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('Pec fly'), findsNothing);
    final fly = await tester.runAsync(
      () => db.workoutDao.exerciseById(ids['fly']!),
    );
    expect(fly!.deletedAt, isNotNull);
    await _dispose(tester, db);
  });
}
