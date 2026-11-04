import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';
import 'entry_view_data.dart';

/// Pure layout for adding or editing a diary entry.
class EntryView extends StatelessWidget {
  const EntryView({
    super.key,
    required this.title,
    required this.body,
    required this.onQuantityChanged,
    required this.onUnitSelected,
    required this.onMealSelected,
    required this.onPickDate,
    required this.onPickTime,
    required this.onSave,
    required this.onDelete,
    required this.onRetry,
  });

  final String title;
  final EntryBody body;
  final ValueChanged<String> onQuantityChanged;
  final ValueChanged<int> onUnitSelected;
  final ValueChanged<MealType> onMealSelected;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: switch (body) {
          EntryLoading() => const Center(child: CircularProgressIndicator()),
          EntryError(:final message) => Padding(
            padding: AppSpacing.screenPadding,
            child: ErrorState(message: message, onRetry: onRetry),
          ),
          final EntryFormData form => _Form(
            form: form,
            onQuantityChanged: onQuantityChanged,
            onUnitSelected: onUnitSelected,
            onMealSelected: onMealSelected,
            onPickDate: onPickDate,
            onPickTime: onPickTime,
            onSave: onSave,
            onDelete: onDelete,
          ),
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.form,
    required this.onQuantityChanged,
    required this.onUnitSelected,
    required this.onMealSelected,
    required this.onPickDate,
    required this.onPickTime,
    required this.onSave,
    required this.onDelete,
  });

  final EntryFormData form;
  final ValueChanged<String> onQuantityChanged;
  final ValueChanged<int> onUnitSelected;
  final ValueChanged<MealType> onMealSelected;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  static const _mealLabels = {
    MealType.breakfast: 'Breakfast',
    MealType.lunch: 'Lunch',
    MealType.dinner: 'Dinner',
    MealType.snack: 'Snack',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(form.foodName, style: t.cardTitle),
              Text(form.foodDetail, style: t.label),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _QuantityField(
                initialText: form.initialQuantity,
                error: form.quantityError,
                onChanged: onQuantityChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var i = 0; i < form.unitLabels.length; i++)
                    ButtonSegment(value: i, label: Text(form.unitLabels[i])),
                ],
                selected: {form.selectedUnit},
                onSelectionChanged: (s) => onUnitSelected(s.single),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('MEAL', style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<MealType>(
          showSelectedIcon: false,
          segments: [
            for (final meal in MealType.values)
              ButtonSegment(
                value: meal,
                label: FittedBox(child: Text(_mealLabels[meal]!)),
              ),
          ],
          selected: {form.meal},
          onSelectionChanged: (s) => onMealSelected(s.single),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListRow(title: 'Date', value: form.dateLabel, onTap: onPickDate),
        const Divider(height: 1),
        ListRow(title: 'Time', value: form.timeLabel, onTap: onPickTime),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          child: StatRow(
            items: [
              StatItem(label: 'Calories', value: form.kcal, unit: 'kcal'),
              StatItem(label: 'Protein', value: form.proteinG, unit: 'g'),
              StatItem(label: 'Carbs', value: form.carbsG, unit: 'g'),
              StatItem(label: 'Fat', value: form.fatG, unit: 'g'),
            ],
          ),
        ),
        if (form.isEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Changing the amount recalculates the nutrients from the '
            "food's current values. Meal, date and time changes keep them.",
            style: t.label,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          style: form.isEdit ? null : AppTheme.accentButton(context),
          onPressed: form.canSave && !form.saving ? onSave : null,
          child: Text(form.isEdit ? 'SAVE' : 'LOG FOOD'),
        ),
        if (form.isEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.error),
            onPressed: form.saving ? null : onDelete,
            child: const Text('Delete entry'),
          ),
        ],
      ],
    );
  }
}

class _QuantityField extends StatefulWidget {
  const _QuantityField({
    required this.initialText,
    required this.error,
    required this.onChanged,
  });

  final String initialText;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  State<_QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<_QuantityField> {
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'Amount', errorText: widget.error),
    );
  }
}
