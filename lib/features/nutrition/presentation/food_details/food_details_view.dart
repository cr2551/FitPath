import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import 'food_details_view_data.dart';

/// Pure layout for inspecting a food before logging it.
class FoodDetailsView extends StatelessWidget {
  const FoodDetailsView({
    super.key,
    required this.body,
    required this.onQuantityChanged,
    required this.onUnitSelected,
    required this.onAddToDiary,
    required this.onEdit,
    required this.onRetry,
  });

  final FoodDetailsBody body;
  final ValueChanged<String> onQuantityChanged;
  final ValueChanged<int> onUnitSelected;
  final VoidCallback onAddToDiary;
  final VoidCallback onEdit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food details')),
      body: SafeArea(
        child: switch (body) {
          FoodDetailsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          FoodDetailsError(:final message) => Padding(
            padding: AppSpacing.screenPadding,
            child: ErrorState(message: message, onRetry: onRetry),
          ),
          final FoodDetailsData d => _Details(
            data: d,
            onQuantityChanged: onQuantityChanged,
            onUnitSelected: onUnitSelected,
            onAddToDiary: onAddToDiary,
            onEdit: onEdit,
          ),
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.data,
    required this.onQuantityChanged,
    required this.onUnitSelected,
    required this.onAddToDiary,
    required this.onEdit,
  });

  final FoodDetailsData data;
  final ValueChanged<String> onQuantityChanged;
  final ValueChanged<int> onUnitSelected;
  final VoidCallback onAddToDiary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
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
              Text(data.name, style: t.cardTitle),
              Text(data.subtitle, style: t.label),
              const SizedBox(height: AppSpacing.xs),
              Text(data.basisLabel, style: t.label),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AmountField(
                text: data.quantity,
                error: data.quantityError,
                onChanged: onQuantityChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var i = 0; i < data.unitLabels.length; i++)
                    ButtonSegment(value: i, label: Text(data.unitLabels[i])),
                ],
                selected: {data.selectedUnit},
                onSelectionChanged: (s) => onUnitSelected(s.single),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          header: Text(data.amountLabel.toUpperCase(), style: t.overline),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < data.nutrients.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListRow(
                  title: data.nutrients[i].label,
                  value: data.nutrients[i].value,
                ),
              ],
            ],
          ),
        ),
        if (data.attribution != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(data.attribution!, style: t.label),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          style: AppTheme.accentButton(context),
          onPressed: onAddToDiary,
          child: const Text('ADD TO DIARY'),
        ),
        if (data.canEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onEdit,
            child: const Text('EDIT CUSTOM FOOD'),
          ),
        ],
      ],
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.text,
    required this.error,
    required this.onChanged,
  });

  /// Kept in sync: a converted amount replaces what is in the field.
  final String text;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(covariant _AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

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
