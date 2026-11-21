import 'package:fitpath/core/startup/splash_overlay.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/shared/widgets/fit_path_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the logo over the app, then removes it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => SplashOverlay(child: child!),
        home: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('APP'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FitPathLogo), findsOneWidget);
    expect(find.text('APP'), findsOneWidget); // built underneath

    // The splash never blocks touches.
    await tester.tap(find.text('APP'));
    expect(taps, 1);

    await tester.pumpAndSettle();
    expect(find.byType(FitPathLogo), findsNothing);
    expect(find.text('APP'), findsOneWidget);
  });
}
