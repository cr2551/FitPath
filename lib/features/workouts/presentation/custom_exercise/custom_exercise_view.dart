import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

/// Form values for a custom exercise.
class CustomExerciseForm {
  const CustomExerciseForm({
    this.name = '',
    this.muscleGroup,
    this.equipment,
    this.isBodyweight = false,
    this.description = '',
  });

  final String name;
  final String? muscleGroup;
  final String? equipment;
  final bool isBodyweight;
  final String description;

  bool get isValid =>
      name.trim().isNotEmpty &&
      name.trim().length <= 120 &&
      muscleGroup != null;

  CustomExerciseForm copyWith({
    String? name,
    String? Function()? muscleGroup,
    String? Function()? equipment,
    bool? isBodyweight,
    String? description,
  }) => CustomExerciseForm(
    name: name ?? this.name,
    muscleGroup: muscleGroup != null ? muscleGroup() : this.muscleGroup,
    equipment: equipment != null ? equipment() : this.equipment,
    isBodyweight: isBodyweight ?? this.isBodyweight,
    description: description ?? this.description,
  );
}

class CustomExerciseCallbacks {
  const CustomExerciseCallbacks({
    required this.onChanged,
    required this.onSave,
    required this.onDelete,
  });

  final ValueChanged<CustomExerciseForm> onChanged;
  final VoidCallback onSave;

  /// Null when creating.
  final VoidCallback? onDelete;
}

/// Pure layout for creating or editing a custom exercise.
class CustomExerciseView extends StatelessWidget {
  const CustomExerciseView({
    super.key,
    required this.title,
    required this.form,
    required this.muscleGroups,
    required this.equipment,
    required this.saving,
    required this.callbacks,
    this.notFound = false,
  });

  final String title;

  /// The exercise to edit does not exist.
  final bool notFound;

  /// Null while loading an existing exercise.
  final CustomExerciseForm? form;
  final List<String> muscleGroups;
  final List<String> equipment;
  final bool saving;
  final CustomExerciseCallbacks callbacks;

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final f = form;
    final cb = callbacks;
    final c = context.fitColors;
    const gap = SizedBox(height: AppSpacing.lg);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: notFound
            ? const Padding(
                padding: AppSpacing.screenPadding,
                child: EmptyState(message: 'This exercise no longer exists.'),
              )
            : f == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: [
                  TextFormField(
                    initialValue: f.name,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (v) => cb.onChanged(f.copyWith(name: v)),
                  ),
                  gap,
                  DropdownButtonFormField<String>(
                    initialValue: f.muscleGroup,
                    decoration: const InputDecoration(
                      labelText: 'Muscle group',
                    ),
                    items: [
                      for (final g in muscleGroups)
                        DropdownMenuItem(value: g, child: Text(_cap(g))),
                    ],
                    onChanged: (v) =>
                        cb.onChanged(f.copyWith(muscleGroup: () => v)),
                  ),
                  gap,
                  DropdownButtonFormField<String?>(
                    initialValue: f.equipment,
                    decoration: const InputDecoration(labelText: 'Equipment'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final e in equipment)
                        DropdownMenuItem(value: e, child: Text(_cap(e))),
                    ],
                    onChanged: (v) =>
                        cb.onChanged(f.copyWith(equipment: () => v)),
                  ),
                  gap,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bodyweight exercise'),
                    subtitle: const Text(
                      'Compared by reps; added weight is optional.',
                    ),
                    value: f.isBodyweight,
                    onChanged: (v) => cb.onChanged(f.copyWith(isBodyweight: v)),
                  ),
                  gap,
                  TextFormField(
                    initialValue: f.description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                    onChanged: (v) => cb.onChanged(f.copyWith(description: v)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: f.isValid && !saving ? cb.onSave : null,
                    child: const Text('SAVE'),
                  ),
                  if (cb.onDelete != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: c.error),
                      onPressed: saving ? null : cb.onDelete,
                      child: const Text('Delete exercise'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
