import 'package:fitpath/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts and shows the home placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitPathApp()));
    await tester.pumpAndSettle();

    expect(find.text('FitPath'), findsOneWidget);
  });
}
