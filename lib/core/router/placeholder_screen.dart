import 'package:flutter/material.dart';

/// Temporary screen shown for routes whose feature is not built yet.
/// Each feature issue replaces its placeholder file with the real screen.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.issue,
  });

  final String title;

  /// The issue that builds this screen.
  final int issue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Coming in #$issue')),
    );
  }
}

/// Shown for unknown locations.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Page not found')),
    );
  }
}
