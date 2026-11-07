import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/seed/exercise_seed.dart';
import '../../../../core/router/routes.dart';
import '../../application/workout_providers.dart';
import 'exercise_picker_view.dart';

/// Picks an exercise for the active session. Pops with the exercise id
/// (`context.pop(id)`), or nothing when the user backs out.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  var _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final filter = (query: _query, muscleGroup: _group);
    final exercises = ref.watch(exercisesProvider(filter));
    return ExercisePickerView(
      onRetry: exercises.hasError && !exercises.hasValue
          ? () => ref.invalidate(exercisesProvider(filter))
          : null,
      muscleGroups: muscleGroups,
      selectedGroup: _group,
      rows: exercises.value == null
          ? null
          : [
              for (final e in exercises.value!)
                ExerciseRowData(
                  id: e.id,
                  name: e.name,
                  detail: [
                    _capitalize(e.muscleGroup),
                    ?e.equipment,
                  ].join(' · '),
                  isCustom: e.isCustom,
                ),
            ],
      callbacks: ExercisePickerCallbacks(
        onQuery: (q) => setState(() => _query = q),
        onMuscleGroup: (g) => setState(() => _group = g),
        onPick: (id) => context.pop(id),
        onEdit: (id) => context.push(Routes.editCustomExercise(id)),
        onCreate: () async {
          final id = await context.push<int>(Routes.newCustomExercise);
          if (id != null && context.mounted) context.pop(id);
        },
      ),
    );
  }
}

String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
