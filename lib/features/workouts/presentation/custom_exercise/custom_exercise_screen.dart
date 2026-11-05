import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/seed/exercise_seed.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../application/workout_providers.dart';
import '../../data/workout_models.dart';
import 'custom_exercise_view.dart';

/// Equipment choices, matching the bundled catalog.
const equipmentTypes = [
  'barbell',
  'dumbbell',
  'machine',
  'cable',
  'kettlebell',
  'bodyweight',
  'other',
];

/// Creates a custom exercise, or edits one when [exerciseId] is given.
/// Pops with the exercise id after saving. Deleting is a soft delete:
/// past sessions keep the exercise under its old name.
class CustomExerciseScreen extends ConsumerStatefulWidget {
  const CustomExerciseScreen({super.key, this.exerciseId});

  final int? exerciseId;

  @override
  ConsumerState<CustomExerciseScreen> createState() =>
      _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends ConsumerState<CustomExerciseScreen> {
  CustomExerciseForm? _form;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final id = widget.exerciseId;
    if (id == null) {
      _form = const CustomExerciseForm();
      return;
    }
    ref.read(workoutRepositoryProvider).exerciseById(id).then((e) {
      if (!mounted || e == null) return;
      setState(
        () => _form = CustomExerciseForm(
          name: e.name,
          muscleGroup: e.muscleGroup,
          equipment: e.equipment,
          isBodyweight: e.isBodyweight,
          description: e.description ?? '',
        ),
      );
    });
  }

  Future<void> _save() async {
    final f = _form!;
    final repo = ref.read(workoutRepositoryProvider);
    final details = ExerciseDetails(
      name: f.name,
      muscleGroup: f.muscleGroup!,
      equipment: f.equipment,
      description: f.description,
      isBodyweight: f.isBodyweight,
    );
    setState(() => _saving = true);
    try {
      final id = widget.exerciseId;
      if (id == null) {
        final created = await repo.createCustomExercise(details);
        if (mounted) context.pop(created);
      } else {
        await repo.updateCustomExercise(id, details);
        if (mounted) context.pop(id);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = e is InvalidExercise
          ? e.message
          : "Couldn't save the exercise.";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this exercise?',
      message:
          'It disappears from the exercise list. Past workouts keep it '
          'under its current name.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref
        .read(workoutRepositoryProvider)
        .deleteCustomExercise(widget.exerciseId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return CustomExerciseView(
      title: widget.exerciseId == null ? 'New exercise' : 'Edit exercise',
      form: _form,
      muscleGroups: muscleGroups,
      equipment: equipmentTypes,
      saving: _saving,
      callbacks: CustomExerciseCallbacks(
        onChanged: (f) => setState(() => _form = f),
        onSave: _save,
        onDelete: widget.exerciseId == null ? null : _delete,
      ),
    );
  }
}
