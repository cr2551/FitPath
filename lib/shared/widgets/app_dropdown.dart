import 'package:flutter/material.dart';

/// One choice in an [AppDropdown].
class DropdownOption<T> {
  const DropdownOption(this.value, this.label);

  final T value;
  final String label;
}

/// A full-width, select-only dropdown field. The flat menu with a 1 px line
/// border comes from the theme's `dropdownMenuTheme`, so every dropdown in
/// the app looks the same and can be restyled in one place.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final List<DropdownOption<T>> options;

  /// Null shows an empty field, unless null is itself an option.
  final T? value;
  final ValueChanged<T> onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      label: Text(label),
      helperText: helperText,
      initialSelection: value,
      expandedInsets: EdgeInsets.zero,
      requestFocusOnTap: false,
      enableFilter: false,
      enableSearch: false,
      menuHeight: 320,
      dropdownMenuEntries: [
        for (final o in options)
          DropdownMenuEntry<T>(value: o.value, label: o.label),
      ],
      onSelected: (v) {
        // A null value is a real choice ("Not set") when T is nullable.
        if (v is T) onChanged(v);
      },
    );
  }
}
