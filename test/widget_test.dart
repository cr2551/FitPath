import 'package:fitpath/app.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('a fresh install opens onboarding', (tester) async {
    final db = createTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitPathApp(),
      ),
    );
    await _settle(tester);
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  testWidgets('after onboarding the app starts on Home with the bottom '
      'navigation', (tester) async {
    final db = createTestDatabase();
    await tester.runAsync(() => db.profileDao.setOnboardingCompleted(true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitPathApp(),
      ),
    );
    await _settle(tester);
    expect(
      find.byWidgetPredicate((w) => w is ScreenHeader && w.title == 'Today'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}
