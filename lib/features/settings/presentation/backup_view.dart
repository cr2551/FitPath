import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';

/// Pure layout for Backup & restore. [restoreSection] is filled by the
/// import feature (#41).
class BackupView extends StatelessWidget {
  const BackupView({
    super.key,
    required this.busy,
    required this.onShare,
    required this.onSave,
    this.restoreSection,
  });

  /// True while a backup is being written; the buttons are disabled.
  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final Widget? restoreSection;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final c = context.fitColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
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
                icon: Icons.phone_android_outlined,
                title: 'Your data stays on this phone',
              ),
              child: Text(
                'FitPath has no account and no cloud copy. Uninstalling the '
                'app or clearing its storage deletes your profile, diary, '
                'workouts and settings. Export a backup file and keep it '
                'somewhere safe, like your cloud drive or email.',
                style: t.body,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              header: const CardHeader(
                icon: Icons.upload_file_outlined,
                title: 'Export a backup',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'One JSON file with everything you entered. It contains '
                    'no passwords or keys.',
                    style: t.label,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    style: AppTheme.accentButton(context),
                    onPressed: busy ? null : onShare,
                    icon: busy
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.inkMuted,
                            ),
                          )
                        : const Icon(Icons.share_outlined),
                    label: const Text('SHARE BACKUP'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onSave,
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('SAVE TO DEVICE'),
                  ),
                ],
              ),
            ),
            if (restoreSection != null) ...[
              const SizedBox(height: AppSpacing.md),
              restoreSection!,
            ],
          ],
        ),
      ),
    );
  }
}
