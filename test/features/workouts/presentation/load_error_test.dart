import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/workouts/presentation/active_session/active_session_view.dart';
import 'package:fitpath/features/workouts/presentation/exercise_picker/exercise_picker_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget view) =>
    tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: view));

void main() {
  testWidgets('the exercise picker shows a retry instead of spinning', (
    tester,
  ) async {
    var retried = 0;
    await _pump(
      tester,
      ExercisePickerView(
        muscleGroups: const ['legs'],
        selectedGroup: null,
        rows: null,
        onRetry: () => retried++,
        callbacks: ExercisePickerCallbacks(
          onQuery: (_) {},
          onMuscleGroup: (_) {},
          onPick: (_) {},
          onEdit: (_) {},
          onCreate: () {},
        ),
      ),
    );
    expect(find.text("Couldn't load exercises."), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('the active workout shows a retry, not "no workout"', (
    tester,
  ) async {
    var retried = 0;
    await _pump(
      tester,
      ActiveSessionView(
        data: null,
        loading: false,
        onRetry: () => retried++,
        callbacks: ActiveSessionCallbacks(
          onRename: (_) {},
          onNotes: (_) {},
          onAddExercise: () {},
          onMoveExercise: (_, _) {},
          onRemoveExercise: (_) {},
          onAddSet: (_) {},
          onDuplicateSet: (_) {},
          onRemoveSet: (_) {},
          onSetValues: (_, _, _) {},
          onSetCompleted: (_, _) {},
          onFinish: () {},
          onDiscard: () {},
          onBackToWorkouts: () {},
        ),
      ),
    );
    expect(find.text("Couldn't load your workout."), findsOneWidget);
    expect(find.text('No workout in progress.'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });
}
