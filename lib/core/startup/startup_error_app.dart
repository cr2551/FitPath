import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/fit_colors.dart';

/// Shown instead of the app when its data cannot be opened.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.details,
    required this.onRetry,
  });

  /// Technical description, shown small for support.
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPath',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Builder(
        builder: (context) {
          final c = context.fitColors;
          final t = context.textStyles;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: c.error, size: 32),
                    const SizedBox(height: AppSpacing.md),
                    Text("FitPath couldn't open its data", style: t.headline),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your data stays on this phone and has not been '
                      'deleted. Check that the device has free storage, '
                      'then try again.',
                      style: t.body,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(details, style: t.label, maxLines: 4),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('TRY AGAIN'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
