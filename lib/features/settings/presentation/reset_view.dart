import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';

/// Pure layout for the reset screen.
class ResetView extends StatelessWidget {
  const ResetView({
    super.key,
    required this.confirmWord,
    required this.canReset,
    required this.resetting,
    required this.onTyped,
    required this.onBackup,
    required this.onReset,
  });

  /// What the user must type to enable the button.
  final String confirmWord;
  final bool canReset;
  final bool resetting;
  final ValueChanged<String> onTyped;
  final VoidCallback onBackup;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.fitColors;
    final t = context.textStyles;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              header: const CardHeader(
                icon: Icons.warning_amber_outlined,
                title: 'This cannot be undone',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resetting deletes everything stored on this phone:',
                    style: t.body,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final line in const [
                    'your profile, goals and weight history',
                    'nutrition targets and your food diary',
                    'custom foods and saved Open Food Facts products',
                    'workouts and custom exercises',
                    'your dashboard layout and preferences',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text('–  $line', style: t.body),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The built-in food and exercise lists stay. The app then '
                    'starts again from the welcome screen.',
                    style: t.label,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Export a backup first if you might want this data again.',
              style: t.bodyStrong,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onBackup,
                child: const Text('Go to Backup & restore'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              onChanged: onTyped,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Type $confirmWord to confirm',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.error,
                foregroundColor: c.surface,
              ),
              onPressed: canReset && !resetting ? onReset : null,
              child: Text(resetting ? 'RESETTING…' : 'RESET ALL DATA'),
            ),
          ],
        ),
      ),
    );
  }
}
