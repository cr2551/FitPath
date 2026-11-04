import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'custom_food_view_data.dart';

/// Pure layout for creating or editing a custom food.
class CustomFoodView extends StatelessWidget {
  const CustomFoodView({
    super.key,
    required this.body,
    required this.onChanged,
    required this.onBasisSelected,
    required this.onServingUnitSelected,
    required this.onSave,
    required this.onDelete,
    required this.onRetry,
  });

  final CustomFoodBody body;
  final void Function(CustomFoodField field, String text) onChanged;
  final ValueChanged<BasisChoice> onBasisSelected;
  final ValueChanged<ServingUnitChoice> onServingUnitSelected;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom food')),
      body: SafeArea(
        child: switch (body) {
          CustomFoodLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          CustomFoodError(:final message) => Padding(
            padding: AppSpacing.screenPadding,
            child: ErrorState(message: message, onRetry: onRetry),
          ),
          final CustomFoodFormData form => _Form(
            form: form,
            onChanged: onChanged,
            onBasisSelected: onBasisSelected,
            onServingUnitSelected: onServingUnitSelected,
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
    required this.onChanged,
    required this.onBasisSelected,
    required this.onServingUnitSelected,
    required this.onSave,
    required this.onDelete,
  });

  final CustomFoodFormData form;
  final void Function(CustomFoodField field, String text) onChanged;
  final ValueChanged<BasisChoice> onBasisSelected;
  final ValueChanged<ServingUnitChoice> onServingUnitSelected;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  Widget _field(
    CustomFoodField field,
    String label, {
    String? suffix,
    String? hint,
    bool number = false,
  }) => _TextInput(
    key: ValueKey(field),
    initialText: form.initialText[field] ?? '',
    label: label,
    suffix: suffix,
    hint: hint,
    number: number,
    error: form.errors[field],
    onChanged: (text) => onChanged(field, text),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    const gap = SizedBox(height: AppSpacing.md);
    final basisLabel = switch (form.basis) {
      BasisChoice.per100g => 'per 100 g',
      BasisChoice.per100ml => 'per 100 ml',
      BasisChoice.perServing => 'per serving',
    };
    final servingRequired = form.basis == BasisChoice.perServing;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        _field(CustomFoodField.name, 'Name'),
        gap,
        _field(CustomFoodField.brand, 'Brand (optional)'),
        const SizedBox(height: AppSpacing.lg),
        Text('VALUES REFER TO', style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<BasisChoice>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: BasisChoice.per100g, label: Text('100 g')),
            ButtonSegment(value: BasisChoice.per100ml, label: Text('100 ml')),
            ButtonSegment(
              value: BasisChoice.perServing,
              label: Text('Serving'),
            ),
          ],
          selected: {form.basis},
          onSelectionChanged: (s) => onBasisSelected(s.single),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          servingRequired ? 'ONE SERVING' : 'SERVING (OPTIONAL)',
          style: t.overline,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(CustomFoodField.servingSize, 'Size', number: true),
            ),
            const SizedBox(width: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SegmentedButton<ServingUnitChoice>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ServingUnitChoice.gram,
                    label: Text('g'),
                  ),
                  ButtonSegment(
                    value: ServingUnitChoice.milliliter,
                    label: Text('ml'),
                  ),
                ],
                selected: {form.servingUnit},
                onSelectionChanged: (s) => onServingUnitSelected(s.single),
              ),
            ),
          ],
        ),
        gap,
        _field(
          CustomFoodField.servingDescription,
          'Description',
          hint: 'e.g. 1 bowl, 1 bar',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('NUTRITION $basisLabel'.toUpperCase(), style: t.overline),
        const SizedBox(height: AppSpacing.xs),
        Text('Leave blank if unknown. Blank is not zero.', style: t.label),
        gap,
        _field(CustomFoodField.kcal, 'Calories', suffix: 'kcal', number: true),
        gap,
        _field(CustomFoodField.protein, 'Protein', suffix: 'g', number: true),
        gap,
        _field(CustomFoodField.carbs, 'Carbs', suffix: 'g', number: true),
        gap,
        _field(CustomFoodField.fat, 'Fat', suffix: 'g', number: true),
        gap,
        _field(CustomFoodField.fiber, 'Fiber', suffix: 'g', number: true),
        gap,
        _field(CustomFoodField.sugar, 'Sugar', suffix: 'g', number: true),
        gap,
        _field(CustomFoodField.sodium, 'Sodium', suffix: 'mg', number: true),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: form.canSave && !form.saving ? onSave : null,
          child: Text(form.isEdit ? 'SAVE' : 'CREATE FOOD'),
        ),
        if (form.isEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.error),
            onPressed: form.saving ? null : onDelete,
            child: const Text('Delete food'),
          ),
        ],
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
    this.suffix,
    this.hint,
    this.number = false,
  });

  final String initialText;
  final String label;
  final String? error;
  final ValueChanged<String> onChanged;
  final String? suffix;
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
        suffixText: widget.suffix,
        errorText: widget.error,
      ),
    );
  }
}
