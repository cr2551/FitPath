import 'package:flutter/material.dart';

import '../../../../core/router/placeholder_screen.dart';

/// PLACEHOLDER created by #3 (App shell and navigation).
/// Replaced by #31, which owns this file.
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Session', issue: 31);
}
