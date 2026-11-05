import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/progress/presentation/weight/weight_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, List<ChartPoint> points) async {
  tester.view.physicalSize = const Size(380, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: WeightChart(points: points, range: RangePreset.days30),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a single entry gets readable, non-repeating labels', (
    tester,
  ) async {
    await _pump(tester, [ChartPoint(DateTime(2026, 11, 5, 9, 43), 163.6)]);
    expect(tester.takeException(), isNull);

    // Each date appears once: the day before to the day after the entry.
    for (final d in ['4 Nov', '5 Nov', '6 Nov', '7 Nov']) {
      expect(find.text(d), findsOneWidget, reason: d);
    }

    // Value labels use whole-unit steps, not 0.1 slices of a flat line.
    final values = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => RegExp(r'^\d+(\.\d+)?$').hasMatch(s))
        .toList();
    expect(values, isNotEmpty);
    expect(values.every((s) => !s.contains('.')), isTrue, reason: '$values');
  });

  testWidgets('entries over several days keep their date axis', (tester) async {
    await _pump(tester, [
      ChartPoint(DateTime(2026, 11, 1, 8), 75),
      ChartPoint(DateTime(2026, 11, 5, 8), 74.2),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('1 Nov'), findsOneWidget);
    expect(find.text('5 Nov'), findsOneWidget);
  });
}
