import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// One completed session in a list, already formatted.
class SessionTileData {
  const SessionTileData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
  });

  final int id;

  /// The session name, or "Workout".
  final String title;

  /// "Mon 2 Nov · 42 min · 9,840 kg"
  final String subtitle;

  /// "5 ex · 18 sets"
  final String detail;
}

/// A completed session row: name and date on the left, totals on the right.
class SessionListTile extends StatelessWidget {
  const SessionListTile({super.key, required this.data, required this.onTap});

  final SessionTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListRow(
    title: data.title,
    subtitle: data.subtitle,
    value: data.detail,
    onTap: onTap,
  );
}
