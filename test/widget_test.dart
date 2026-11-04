import 'package:fitpath/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts on Home with the bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitPathApp()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Today'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
