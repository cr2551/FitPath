import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/fit_colors.dart';
import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/widgets/widgets.dart';

/// What the weight entry dialog returns.
sealed class WeightDialogResult {
  const WeightDialogResult();
}

class SaveWeight extends WeightDialogResult {
  const SaveWeight({required this.kg, required this.at, this.notes});

  final double kg;
  final DateTime at;
  final String? notes;
}

class DeleteWeight extends WeightDialogResult {
  const DeleteWeight();
}

/// Logs a new weight, or edits one when [initialKg] is given (then it also
/// offers Delete). The value is entered in the user's units and returned in
/// kg. Dates in the future are not allowed.
Future<WeightDialogResult?> showWeightEntryDialog(
  BuildContext context, {
  required UnitSystem units,
  double? initialKg,
  DateTime? initialAt,
  String? initialNotes,
  bool editing = false,
}) => showDialog<WeightDialogResult>(
  context: context,
  builder: (_) => _WeightEntryDialog(
    units: units,
    initialKg: initialKg,
    initialAt: initialAt ?? DateTime.now(),
    initialNotes: initialNotes,
    editing: editing,
  ),
);

class _WeightEntryDialog extends StatefulWidget {
  const _WeightEntryDialog({
    required this.units,
    required this.initialKg,
    required this.initialAt,
    required this.initialNotes,
    required this.editing,
  });

  final UnitSystem units;
  final double? initialKg;
  final DateTime initialAt;
  final String? initialNotes;
  final bool editing;

  @override
  State<_WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<_WeightEntryDialog> {
  late double? _value = widget.initialKg == null
      ? null
      : Units.weightForDisplay(widget.initialKg!, widget.units);
  late DateTime _at = widget.initialAt;
  late final _notes = TextEditingController(text: widget.initialNotes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _at.isAfter(now) ? now : _at,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked == null) return;
    // Keep the time of day; today's entries use the current time.
    final sameDay =
        picked.year == now.year &&
        picked.month == now.month &&
        picked.day == now.day;
    setState(
      () => _at = sameDay
          ? now
          : DateTime(
              picked.year,
              picked.month,
              picked.day,
              _at.hour,
              _at.minute,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imperial = widget.units == UnitSystem.imperial;
    final range = imperial
        ? ValueRange(
            Units.kgToLb(PlausibleRanges.weightKg.min),
            Units.kgToLb(PlausibleRanges.weightKg.max),
          )
        : PlausibleRanges.weightKg;
    final c = context.fitColors;
    return AlertDialog(
      title: Text(widget.editing ? 'Edit weight' : 'Log weight'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UnitNumberField(
            label: 'Weight',
            unit: Units.weightUnit(widget.units),
            range: range,
            initialValue: _value,
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(DateFormat('EEE d MMM y').format(_at)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
      ),
      actions: [
        if (widget.editing)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.error),
            onPressed: () => Navigator.of(context).pop(const DeleteWeight()),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _value == null
              ? null
              : () => Navigator.of(context).pop(
                  SaveWeight(
                    kg: Units.weightFromInput(_value!, widget.units),
                    at: _at,
                    notes: _notes.text.trim().isEmpty
                        ? null
                        : _notes.text.trim(),
                  ),
                ),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
