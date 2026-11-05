import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class ExerciseRowData {
  const ExerciseRowData({
    required this.id,
    required this.name,
    required this.detail,
    required this.isCustom,
  });

  final int id;
  final String name;

  /// "Chest · barbell"
  final String detail;
  final bool isCustom;
}

class ExercisePickerCallbacks {
  const ExercisePickerCallbacks({
    required this.onQuery,
    required this.onMuscleGroup,
    required this.onPick,
    required this.onEdit,
    required this.onCreate,
  });

  final ValueChanged<String> onQuery;

  /// Null clears the filter.
  final ValueChanged<String?> onMuscleGroup;
  final ValueChanged<int> onPick;
  final ValueChanged<int> onEdit;
  final VoidCallback onCreate;
}

/// Pure layout for the exercise picker: search, muscle-group chips, list.
class ExercisePickerView extends StatelessWidget {
  const ExercisePickerView({
    super.key,
    required this.muscleGroups,
    required this.selectedGroup,
    required this.rows,
    required this.callbacks,
  });

  final List<String> muscleGroups;
  final String? selectedGroup;

  /// Null while loading.
  final List<ExerciseRowData>? rows;
  final ExercisePickerCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final cb = callbacks;
    final t = context.textStyles;
    final rows = this.rows;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add exercise'),
        actions: [
          IconButton(
            tooltip: 'Create custom exercise',
            onPressed: cb.onCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: TextField(
                onChanged: cb.onQuery,
                decoration: const InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.screenPadding,
                children: [
                  for (final g in [null, ...muscleGroups])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(g == null ? 'All' : _capitalize(g)),
                        selected: g == selectedGroup,
                        onSelected: (_) => cb.onMuscleGroup(g),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: rows == null
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                  ? Padding(
                      padding: AppSpacing.screenPadding,
                      child: EmptyState(
                        message: 'No exercises match.',
                        actionLabel: 'Create one',
                        onAction: cb.onCreate,
                      ),
                    )
                  : ListView.separated(
                      padding: AppSpacing.screenPadding,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return ListRow(
                          title: r.name,
                          subtitle: r.isCustom
                              ? '${r.detail} · Custom'
                              : r.detail,
                          onTap: () => cb.onPick(r.id),
                          trailing: r.isCustom
                              ? IconButton(
                                  tooltip: 'Edit ${r.name}',
                                  onPressed: () => cb.onEdit(r.id),
                                  icon: const Icon(Icons.edit_outlined),
                                )
                              : Icon(Icons.add, color: t.label.color),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
