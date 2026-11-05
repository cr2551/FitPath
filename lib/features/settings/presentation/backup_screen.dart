import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database_provider.dart';
import '../backup/export_service.dart';
import 'backup_view.dart';

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(appDatabaseProvider)),
);

/// "1.0.0+1" from the platform package info.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// How a finished backup leaves the app. Overridden in tests.
class BackupDelivery {
  const BackupDelivery();

  /// Opens the share sheet with the file.
  Future<void> share(String fileName, String json) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'FitPath backup',
      ),
    );
  }

  /// Asks where to save the file. Returns false if the user cancelled.
  Future<bool> save(String fileName, String json) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    return uri != null;
  }
}

final backupDeliveryProvider = Provider<BackupDelivery>(
  (ref) => const BackupDelivery(),
);

/// Backup & restore: exports every user-owned record as one JSON file.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  var _busy = false;

  Future<void> _export({required bool save}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await ref
          .read(exportServiceProvider)
          .buildBackup(appVersion: await ref.read(appVersionProvider.future));
      final json = ExportService.encode(doc);
      final name = ExportService.fileName(doc.exportedAt);
      final delivery = ref.read(backupDeliveryProvider);
      if (save) {
        if (await delivery.save(name, json)) {
          messenger.showSnackBar(SnackBar(content: Text('Saved $name')));
        }
      } else {
        await delivery.share(name, json);
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't create the backup.")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackupView(
      busy: _busy,
      onShare: () => _export(save: false),
      onSave: () => _export(save: true),
    );
  }
}
