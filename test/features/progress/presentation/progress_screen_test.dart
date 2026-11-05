import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/progress/application/progress_range_provider.dart';
import 'package:fitpath/features/progress/presentation/charts/chart_helpers.dart';
import 'package:fitpath/features/progress/presentation/nutrition/nutrition_progress_view.dart';
import 'package:fitpath/features/progress/presentation/progress_screen.dart';
import 'package:fitpath/features/progress/presentation/weight/weight_progress_view.dart';
import 'package:fitpath/features/progress/presentation/workouts/workout_progress_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  testWidgets('tabs switch the body and share one range', (tester) async {
    final db = createTestDatabase();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const ProgressScreen()),
      ),
    );

    expect(find.byType(WeightProgressView), findsOneWidget);
    expect(container.read(progressRangeProvider), RangePreset.days30);

    await tester.tap(find.text('90 D'));
    await tester.pump();
    expect(container.read(progressRangeProvider), RangePreset.days90);

    await tester.tap(find.text('NUTRITION'));
    await tester.pump();
    expect(find.byType(NutritionProgressView), findsOneWidget);
    expect(container.read(progressRangeProvider), RangePreset.days90);

    await tester.tap(find.text('WORKOUTS'));
    await tester.pump();
    expect(find.byType(WorkoutProgressView), findsOneWidget);
    expect(container.read(progressRangeProvider), RangePreset.days90);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });

  group('chart helpers', () {
    test('date labels depend on the range', () {
      final d = DateTime(2026, 11, 3);
      expect(ChartAxes.dateLabel(d, RangePreset.days30), '3 Nov');
      expect(ChartAxes.dateLabel(d, RangePreset.year), 'Nov 26');
    });

    test('value labels drop trailing zeros', () {
      expect(ChartAxes.valueLabel(74), '74');
      expect(ChartAxes.valueLabel(74.5), '74.5');
      expect(ChartAxes.valueLabel(74.25, decimals: 2), '74.25');
      expect(ChartAxes.valueLabel(1640, decimals: 0), '1640');
    });

    test('range wording', () {
      expect(ChartAxes.rangeLabel(RangePreset.all), 'All');
      expect(ChartAxes.rangePhrase(RangePreset.days30), 'over 30 days');
    });

    testWidgets('empty chart and legend render', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                EmptyChart(
                  message: 'No weight entries in this range',
                  actionLabel: 'Log weight',
                  onAction: () => tapped = true,
                ),
                const ChartLegend(
                  items: [
                    LegendItem('Measured', SeriesStyle.measured),
                    LegendItem('Target', SeriesStyle.target),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('No weight entries in this range'), findsOneWidget);
      expect(find.text('Measured'), findsOneWidget);
      await tester.tap(find.text('Log weight'));
      expect(tapped, isTrue);
    });
  });
}
