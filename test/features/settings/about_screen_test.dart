import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/settings/presentation/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('shows version, disclaimer, attribution and licences', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'FitPath',
      packageName: 'com.example.fitpath',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.0+1'), findsOneWidget);
    expect(find.text('Health disclaimer'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
    expect(find.text('Open Food Facts'), findsOneWidget);
    expect(find.textContaining('Open Database License (ODbL)'), findsOneWidget);
    expect(find.text(privacyPolicyUrl), findsOneWidget);

    await tester.tap(find.text('Open-source licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
