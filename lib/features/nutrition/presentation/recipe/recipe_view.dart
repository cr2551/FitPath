import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/extensions/text_scale.dart';
import '../../../../shared/widgets/widgets.dart';
import 'recipe_view_data.dart';

/// Pure layout for building or editing a recipe.
class RecipeView extends StatelessWidget {
  const RecipeView({
    super.key,
    required this.body,
    required this.onChanged,
    required this.onAddIngredient,
    required this.onQuantityChanged,
    required this.onUnitSelected,
    required this.onIngredientAction,
    required this.onSave,
    required this.onDelete,
    required this.onRetry,
  });

  final RecipeBody body;
  final void Function(RecipeField field, String text) onChanged;
  final VoidCallback onAddIngredient;
  final void Function(int key, String text) onQuantityChanged;
  final void Function(int key, int unitIndex) onUnitSelected;
  final void Function(int key, IngredientAction action) onIngredientAction;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final b = body;
    return Scaffold(
      appBar: AppBar(
        title: Text(b is RecipeFormData && !b.isEdit ? 'New recipe' : 'Recipe'),
      ),
      body: SafeArea(
        child: switch (b) {
          RecipeLoading() => const Center(child: CircularProgressIndicator()),
          RecipeError(:final message) => Padding(
            padding: AppSpacing.screenPadding,
            child: ErrorState(message: message, onRetry: onRetry),
          ),
          final RecipeFormData form => _Form(view: this, form: form),
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.view, required this.form});

  final RecipeView view;
  final RecipeFormData form;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    const gap = SizedBox(height: AppSpacing.md);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        _TextInput(
          key: const ValueKey(RecipeField.name),
          initialText: form.initialName,
          label: 'Name',
          error: form.nameError,
          onChanged: (text) => view.onChanged(RecipeField.name, text),
        ),
        gap,
        _TextInput(
          key: const ValueKey(RecipeField.servings),
          initialText: form.initialServings,
          label: 'Servings',
          hint: 'How many portions it makes',
          number: true,
          error: form.servingsError,
          onChanged: (text) => view.onChanged(RecipeField.servings, text),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('INGREDIENTS', style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        if (form.ingredients.isEmpty)
          const EmptyState(message: 'No ingredients yet. Add at least one.')
        else
          SectionCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in form.ingredients.indexed) ...[
                  if (i > 0) const Divider(height: AppSpacing.lg),
                  _IngredientRow(key: ValueKey(row.key), row: row, view: view),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: form.saving ? null : view.onAddIngredient,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add ingredient'),
          ),
        ),
        if (form.perServing.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            header: Text('PER SERVING', style: t.overline),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, line) in form.perServing.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListRow(title: line.label, value: line.value),
                ],
              ],
            ),
          ),
          for (final note in form.notes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(note, style: t.label),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: form.canSave && !form.saving ? view.onSave : null,
          child: Text(form.isEdit ? 'SAVE' : 'CREATE RECIPE'),
        ),
        if (form.isEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.error),
            onPressed: form.saving ? null : view.onDelete,
            child: const Text('Delete recipe'),
          ),
        ],
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({super.key, required this.row, required this.view});

  final IngredientRowData row;
  final RecipeView view;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    // Large text stacks what otherwise sits side by side.
    final large = context.hasLargeText;
    final amount = _TextInput(
      initialText: row.initialQuantity,
      label: 'Amount',
      number: true,
      error: row.quantityError,
      onChanged: (text) => view.onQuantityChanged(row.key, text),
    );
    final units = SegmentedButton<int>(
      showSelectedIcon: false,
      segments: [
        for (final (i, label) in row.unitLabels.indexed)
          ButtonSegment(value: i, label: Text(label)),
      ],
      selected: {row.selectedUnit},
      onSelectionChanged: (s) => view.onUnitSelected(row.key, s.single),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name, style: t.bodyStrong),
                  Text(row.detail, style: t.label),
                  if (large) Text(row.kcal, style: t.label),
                ],
              ),
            ),
            if (!large) Text(row.kcal, style: t.label),
            PopupMenuButton<IngredientAction>(
              tooltip: 'Ingredient options',
              onSelected: (a) => view.onIngredientAction(row.key, a),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: IngredientAction.moveUp,
                  enabled: row.canMoveUp,
                  child: const Text('Move up'),
                ),
                PopupMenuItem(
                  value: IngredientAction.moveDown,
                  enabled: row.canMoveDown,
                  child: const Text('Move down'),
                ),
                const PopupMenuItem(
                  value: IngredientAction.remove,
                  child: Text('Remove'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    amount,
                    const SizedBox(height: AppSpacing.sm),
                    units,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: amount),
                    const SizedBox(width: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: units,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    super.key,
    required this.initialText,
    required this.label,
    required this.error,
    required this.onChanged,
    this.hint,
    this.number = false,
  });

  final String initialText;
  final String label;
  final String? error;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool number;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: widget.number
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.error,
      ),
    );
  }
}
