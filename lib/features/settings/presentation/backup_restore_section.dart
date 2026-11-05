import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/fit_colors.dart';
import '../../../shared/widgets/widgets.dart';
import '../backup/backup_validator.dart';
import '../backup/import_service.dart';

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(appDatabaseProvider)),
);

/// Opens the system file picker and returns the chosen file's text, or null
/// when cancelled. Overridden in tests.
final backupFilePickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    return files.single.xFile.readAsString();
  },
);

/// "Restore from a backup": pick a file, check it completely, show what it
/// contains and confirm, offering to export the current data first, then
/// replace everything in one transaction.
class BackupRestoreSection extends ConsumerStatefulWidget {
  const BackupRestoreSection({super.key, required this.onExportFirst});

  /// Shares a backup of the current data.
  final Future<void> Function() onExportFirst;

  @override
  ConsumerState<BackupRestoreSection> createState() =>
      _BackupRestoreSectionState();
}

enum _Choice { exportFirst, restore }

class _BackupRestoreSectionState extends ConsumerState<BackupRestoreSection> {
  var _busy = false;

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await ref.read(backupFilePickerProvider)();
    if (text == null || !mounted) return;

    final ValidBackup backup;
    try {
      backup = BackupValidator.parse(text);
    } on InvalidBackup catch (e) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Can't restore this file"),
          content: Text('${e.message}\n\nNothing was changed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;

    final choice = await _confirm(backup);
    if (choice == null || !mounted) return;
    if (choice == _Choice.exportFirst) {
      await widget.onExportFirst();
      if (!mounted) return;
      if (await _confirm(backup, afterExport: true) != _Choice.restore) {
        return;
      }
    }

    setState(() => _busy = true);
    try {
      await ref.read(importServiceProvider).restore(backup);
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored.')));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't restore the backup. Nothing was changed."),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_Choice?> _confirm(ValidBackup b, {bool afterExport = false}) {
    final c = context.fitColors;
    final sessions = b.sessions.length;
    final summary = [
      '${b.entries.length} diary entries',
      '$sessions ${sessions == 1 ? 'workout' : 'workouts'}',
      '${b.weights.length} weight entries',
    ].join(', ');
    return showDialog<_Choice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace your data?'),
        content: Text(
          'Backup from ${DateFormat('d MMM y, HH:mm').format(b.exportedAt.toLocal())}: '
          '$summary.\n\n'
          'Restoring replaces everything on this phone with the backup. '
          "This can't be undone.",
        ),
        actions: [
          if (!afterExport)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_Choice.exportFirst),
              child: const Text('Export current first'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.error,
              foregroundColor: c.surface,
            ),
            onPressed: () => Navigator.of(context).pop(_Choice.restore),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return SectionCard(
      header: const CardHeader(
        icon: Icons.settings_backup_restore,
        title: 'Restore from a backup',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Replaces everything on this phone with the contents of a '
            'FitPath backup file. The file is checked first; if anything is '
            'wrong, nothing changes.',
            style: t.label,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('CHOOSE BACKUP FILE'),
          ),
        ],
      ),
    );
  }
}
