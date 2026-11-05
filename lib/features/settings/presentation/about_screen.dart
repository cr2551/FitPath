import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'about_view.dart';

/// Published from `docs/privacy-policy.md` via GitHub Pages.
const privacyPolicyUrl = 'https://cr2551.github.io/FitPath/privacy-policy';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// About & disclaimer: version, health disclaimer, privacy, data
/// attribution and the open-source licences.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(_versionProvider).value;
    return AboutView(
      version: version,
      privacyPolicyUrl: privacyPolicyUrl,
      onLicenses: () => showLicensePage(
        context: context,
        applicationName: 'FitPath',
        applicationVersion: version,
      ),
    );
  }
}
