import 'package:fitpath/app.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/shared/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  testWidgets('app starts on Home with the bottom navigation', (tester) async {
    final db = createTestDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const FitPathApp(),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

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
