import 'package:flutter/material.dart';

import '../../../core/utils/units.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/widgets.dart';

/// Asks for a weight in the user's units. Returns it in kg, or null when
/// cancelled. Saving is up to the caller.
Future<double?> showLogWeightDialog(
  BuildContext context, {
  required UnitSystem units,
  double? initialKg,
}) => showDialog<double>(
  context: context,
  builder: (_) => _LogWeightDialog(units: units, initialKg: initialKg),
);

class _LogWeightDialog extends StatefulWidget {
  const _LogWeightDialog({required this.units, this.initialKg});

  final UnitSystem units;
  final double? initialKg;

  @override
  State<_LogWeightDialog> createState() => _LogWeightDialogState();
}

class _LogWeightDialogState extends State<_LogWeightDialog> {
  late double? _value = widget.initialKg == null
      ? null
      : Units.weightForDisplay(widget.initialKg!, widget.units);

  @override
  Widget build(BuildContext context) {
    final imperial = widget.units == UnitSystem.imperial;
    final range = imperial
        ? ValueRange(
            Units.kgToLb(PlausibleRanges.weightKg.min),
            Units.kgToLb(PlausibleRanges.weightKg.max),
          )
        : PlausibleRanges.weightKg;
    return AlertDialog(
      title: const Text('Log weight'),
      content: UnitNumberField(
        label: 'Weight',
        unit: Units.weightUnit(widget.units),
        range: range,
        initialValue: _value,
        onChanged: (v) => setState(() => _value = v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _value == null
              ? null
              : () =>
                    Navigator.of(context)
                        .pop(Units.weightFromInput(_value!, widget.units)),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
