import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/units.dart';

/// Numeric input with a unit suffix and range validation. Accepts `74.2` or
/// `74,2`. Reports the parsed value, or null while the input is empty or
/// invalid, so the form can disable "Next" until it is valid.
class UnitNumberField extends StatefulWidget {
  const UnitNumberField({
    super.key,
    required this.label,
    required this.unit,
    required this.range,
    required this.onChanged,
    this.initialValue,
    this.decimals = 1,
    this.isRequired = true,
    this.hint,
  });

  final String label;
  final String unit;

  /// Allowed values, inclusive, in the DISPLAY unit.
  final ValueRange range;
  final ValueChanged<double?> onChanged;
  final double? initialValue;

  /// Decimal places allowed (0 = whole numbers).
  final int decimals;
  final bool isRequired;
  final String? hint;

  @override
  State<UnitNumberField> createState() => _UnitNumberFieldState();
}

class _UnitNumberFieldState extends State<UnitNumberField> {
  late final TextEditingController _controller;
  String? _error;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initialValue;
    _controller = TextEditingController(text: v == null ? '' : _format(v));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) => widget.decimals == 0
      ? v.round().toString()
      : v.toStringAsFixed(widget.decimals).replaceFirst(RegExp(r'\.?0+$'), '');

  String _bound(double v) => _format(v);

  void _onChanged(String text) {
    _touched = true;
    final value = Units.parseDecimal(text);
    String? error;
    if (text.trim().isEmpty) {
      error = widget.isRequired ? 'Required' : null;
    } else if (value == null) {
      error = 'Enter a number';
    } else if (!widget.range.contains(value)) {
      error =
          'Enter a value between ${_bound(widget.range.min)} and '
          '${_bound(widget.range.max)} ${widget.unit}';
    }
    setState(() => _error = error);
    widget.onChanged(error == null ? value : null);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.decimals > 0,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(widget.decimals > 0 ? r'[0-9.,]' : r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixText: widget.unit,
        errorText: _touched ? _error : null,
      ),
    );
  }
}
