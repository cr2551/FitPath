import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/widgets/widgets.dart';
import 'active_session_view_data.dart';

class ActiveSessionCallbacks {
  const ActiveSessionCallbacks({
    required this.onRename,
    required this.onNotes,
    required this.onAddExercise,
    required this.onMoveExercise,
    required this.onRemoveExercise,
    required this.onAddSet,
    required this.onDuplicateSet,
    required this.onRemoveSet,
    required this.onSetValues,
    required this.onSetCompleted,
    required this.onFinish,
    required this.onDiscard,
    required this.onBackToWorkouts,
  });

  final ValueChanged<String> onRename;
  final ValueChanged<String> onNotes;
  final VoidCallback onAddExercise;

  /// Moves an exercise up (-1) or down (+1).
  final void Function(int exerciseId, int delta) onMoveExercise;
  final ValueChanged<int> onRemoveExercise;
  final ValueChanged<int> onAddSet;
  final ValueChanged<int> onDuplicateSet;
  final ValueChanged<int> onRemoveSet;

  /// Valid values only; null means empty.
  final void Function(int setId, int? reps, double? load) onSetValues;
  final void Function(int setId, bool completed) onSetCompleted;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;
  final VoidCallback onBackToWorkouts;
}

/// Pure layout for the workout in progress: name, notes and timer, one
/// card per exercise with its sets table, then finish or discard.
class ActiveSessionView extends StatelessWidget {
  const ActiveSessionView({
    super.key,
    required this.data,
    required this.loading,
    required this.callbacks,
    this.onRetry,
  });

  /// Null when no session is in progress (and not [loading]).
  final ActiveSessionViewData? data;
  final bool loading;
  final ActiveSessionCallbacks callbacks;

  /// Set when the session failed to load.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final cb = callbacks;
    final t = context.textStyles;
    final c = context.fitColors;
    const gap = SizedBox(height: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: SafeArea(
        child: onRetry != null
            ? Padding(
                padding: AppSpacing.screenPadding,
                child: ErrorState(
                  message: "Couldn't load your workout.",
                  onRetry: onRetry,
                ),
              )
            : loading
            ? const Center(child: CircularProgressIndicator())
            : d == null
            ? Padding(
                padding: AppSpacing.screenPadding,
                child: EmptyState(
                  message: 'No workout in progress.',
                  actionLabel: 'Workouts',
                  onAction: cb.onBackToWorkouts,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: [
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${d.completedSets} of ${d.totalSets} sets done',
                                style: t.label,
                              ),
                            ),
                            Icon(Icons.timer_outlined, size: 16, color: c.ink),
                            const SizedBox(width: AppSpacing.xs),
                            Text(d.elapsed, style: t.bodyStrong),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _TextInput(
                          key: ValueKey(('name', d.sessionId)),
                          initial: d.name,
                          label: 'Workout name',
                          onChanged: cb.onRename,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _TextInput(
                          key: ValueKey(('notes', d.sessionId)),
                          initial: d.notes,
                          label: 'Notes',
                          maxLines: 3,
                          onChanged: cb.onNotes,
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < d.exercises.length; i++) ...[
                    gap,
                    _ExerciseCard(
                      key: ValueKey(d.exercises[i].id),
                      data: d.exercises[i],
                      loadUnit: d.loadUnit,
                      maxLoad: d.maxLoad,
                      isFirst: i == 0,
                      isLast: i == d.exercises.length - 1,
                      callbacks: cb,
                    ),
                  ],
                  gap,
                  OutlinedButton.icon(
                    onPressed: cb.onAddExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD EXERCISE'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    style: AppTheme.accentButton(context),
                    onPressed: cb.onFinish,
                    child: const Text('FINISH WORKOUT'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: c.error),
                    onPressed: cb.onDiscard,
                    child: const Text('Discard workout'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A text field that keeps its own controller, so stream rebuilds don't
/// reset what is being typed.
class _TextInput extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.initial,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String initial;
  final String label;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    minLines: 1,
    maxLines: widget.maxLines,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(labelText: widget.label),
    onChanged: widget.onChanged,
  );
}

enum _ExerciseAction { up, down, remove }

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    super.key,
    required this.data,
    required this.loadUnit,
    required this.maxLoad,
    required this.isFirst,
    required this.isLast,
    required this.callbacks,
  });

  final ExerciseBlockData data;
  final String loadUnit;
  final double maxLoad;
  final bool isFirst;
  final bool isLast;
  final ActiveSessionCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final cb = callbacks;
    final d = data;
    final head = t.overline;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      header: Row(
        children: [
          Expanded(child: Text(d.name, style: t.cardTitle)),
          PopupMenuButton<_ExerciseAction>(
            tooltip: 'Exercise options',
            onSelected: (a) => switch (a) {
              _ExerciseAction.up => cb.onMoveExercise(d.id, -1),
              _ExerciseAction.down => cb.onMoveExercise(d.id, 1),
              _ExerciseAction.remove => cb.onRemoveExercise(d.id),
            },
            itemBuilder: (_) => [
              if (!isFirst)
                const PopupMenuItem(
                  value: _ExerciseAction.up,
                  child: Text('Move up'),
                ),
              if (!isLast)
                const PopupMenuItem(
                  value: _ExerciseAction.down,
                  child: Text('Move down'),
                ),
              const PopupMenuItem(
                value: _ExerciseAction.remove,
                child: Text('Remove exercise'),
              ),
            ],
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(width: 36, child: Text('SET', style: head)),
                Expanded(
                  child: Text(
                    d.isBodyweight
                        ? '+$loadUnit'.toUpperCase()
                        : loadUnit.toUpperCase(),
                    style: head,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('REPS', style: head)),
                const SizedBox(width: 88),
              ],
            ),
            for (final s in d.sets)
              _SetRow(
                key: ValueKey(s.id),
                data: s,
                maxLoad: maxLoad,
                exerciseName: d.name,
                callbacks: cb,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => cb.onAddSet(d.id),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SetAction { duplicate, remove }

/// One set: number, load and reps inputs, done checkbox and a menu.
/// Inputs keep their own text; only valid values are reported.
class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.data,
    required this.maxLoad,
    required this.exerciseName,
    required this.callbacks,
  });

  final SetRowData data;
  final double maxLoad;
  final String exerciseName;
  final ActiveSessionCallbacks callbacks;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final _load = TextEditingController(text: _fmt(widget.data.load));
  late final _reps = TextEditingController(
    text: widget.data.reps?.toString() ?? '',
  );
  var _loadError = false;
  var _repsError = false;

  static String _fmt(double? v) =>
      v == null ? '' : v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  @override
  void dispose() {
    _load.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _changed() {
    final loadText = _load.text.trim(), repsText = _reps.text.trim();
    final load = loadText.isEmpty ? null : Units.parseDecimal(loadText);
    final reps = repsText.isEmpty ? null : int.tryParse(repsText);
    final loadBad =
        loadText.isNotEmpty &&
        (load == null || load < 0 || load > widget.maxLoad);
    final repsBad =
        repsText.isNotEmpty && (reps == null || reps < 0 || reps > 1000);
    setState(() {
      _loadError = loadBad;
      _repsError = repsBad;
    });
    if (!loadBad && !repsBad) {
      widget.callbacks.onSetValues(widget.data.id, reps, load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.data;
    final cb = widget.callbacks;
    final t = context.textStyles;
    InputDecoration deco(bool error, String label) => InputDecoration(
      isDense: true,
      errorText: error ? '' : null,
      errorStyle: const TextStyle(height: 0),
      hintText: '—',
      semanticCounterText: label,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('${s.number}', style: t.bodyStrong)),
          Expanded(
            child: Semantics(
              label: '${widget.exerciseName} set ${s.number} load',
              child: TextField(
                controller: _load,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                ],
                decoration: deco(_loadError, 'load'),
                onChanged: (_) => _changed(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              label: '${widget.exerciseName} set ${s.number} reps',
              child: TextField(
                controller: _reps,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: deco(_repsError, 'reps'),
                onChanged: (_) => _changed(),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Checkbox(
              value: s.completed,
              semanticLabel: 'Set ${s.number} done',
              onChanged: (v) => cb.onSetCompleted(s.id, v ?? false),
            ),
          ),
          SizedBox(
            width: 40,
            child: PopupMenuButton<_SetAction>(
              tooltip: 'Set ${s.number} options',
              padding: EdgeInsets.zero,
              onSelected: (a) => switch (a) {
                _SetAction.duplicate => cb.onDuplicateSet(s.id),
                _SetAction.remove => cb.onRemoveSet(s.id),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _SetAction.duplicate,
                  child: Text('Duplicate set'),
                ),
                PopupMenuItem(
                  value: _SetAction.remove,
                  child: Text('Remove set'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
