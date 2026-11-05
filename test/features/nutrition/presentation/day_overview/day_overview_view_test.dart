import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/features/nutrition/presentation/day_overview/day_overview_view.dart';
import 'package:fitpath/features/nutrition/presentation/day_overview/day_overview_view_data.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final day = DateTime(2026, 11, 3);

DayOverviewViewData _data(DayBody body) => DayOverviewViewData(
  week: Dates.weekOf(day),
  selected: day,
  today: day,
  weekLabel: '1 – 7 Nov',
  canGoToNextWeek: false,
  daysWithEntries: const {},
  body: body,
);

const _summary = DaySummaryViewData(
  eatenKcal: 2300,
  goalKcal: 2100,
  proteinKcal: 600,
  carbsKcal: 1000,
  fatKcal: 500,
  unknownKcal: 200,
  macros: [
    MacroBarData(
      kind: MacroKind.protein,
      label: 'Prot.',
      consumedG: 150,
      targetG: 140,
    ),
    MacroBarData(
      kind: MacroKind.carbs,
      label: 'Carbs',
      consumedG: 250,
      targetG: null,
    ),
    MacroBarData(kind: MacroKind.fat, label: 'Fat', consumedG: 55, targetG: 70),
  ],
  note: '1 entry has incomplete macro data',
);

Future<List<String>> _pump(WidgetTester tester, DayBody body) async {
  final calls = <String>[];
  tester.view.physicalSize = const Size(360, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: DayOverviewView(
        data: _data(body),
        onSelectDay: (d) => calls.add('day ${d.day}'),
        onPreviousWeek: () => calls.add('prev'),
        onNextWeek: () => calls.add('next'),
        onSearch: () => calls.add('search'),
        onCreateCustomFood: () => calls.add('custom'),
        onAddToMeal: (m) => calls.add('add ${m.name}'),
        onEditEntry: (id) => calls.add('edit $id'),
        onDeleteEntry: (id) => calls.add('delete $id'),
        onSetTargets: () => calls.add('targets'),
        onRetry: () => calls.add('retry'),
      ),
    ),
  );
  return calls;
}

void main() {
  testWidgets('loading and error states', (tester) async {
    await _pump(tester, const DayLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final calls = await _pump(tester, const DayError('Could not load.'));
    expect(find.text('Could not load.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(calls, ['retry']);
  });

  testWidgets('over target, missing data and meal actions', (tester) async {
    final calls = await _pump(
      tester,
      const DayLoaded(
        summary: _summary,
        meals: [
          MealGroupViewData(
            meal: MealType.breakfast,
            title: 'Breakfast',
            totalLabel: '146 kcal',
            entries: [
              EntryRowData(
                id: 7,
                name: 'Greek yogurt',
                detail: '200 g · Fage',
                kcal: '146',
              ),
            ],
          ),
          MealGroupViewData(
            meal: MealType.dinner,
            title: 'Dinner',
            totalLabel: '',
            entries: [],
          ),
        ],
      ),
    );

    expect(find.text('200 over', findRichText: true), findsOneWidget);
    expect(find.text('110%'), findsOneWidget);
    expect(find.text('1 entry has incomplete macro data'), findsOneWidget);
    expect(find.text('—'), findsNothing); // empty dinner shows no total
    expect(find.text('250 g'), findsOneWidget); // carbs without a target
    expect(find.text('Set targets'), findsNothing);

    await tester.tap(find.text('Greek yogurt'));
    await tester.tap(find.text('Add food'));
    await tester.tap(find.byTooltip('Add to Breakfast'));
    await tester.tap(find.byType(TextField));
    await tester.tap(find.byTooltip('Create custom food'));
    await tester.tap(find.byTooltip('Previous week'));
    await tester.tap(find.byTooltip('Next week')); // disabled
    expect(calls, [
      'edit 7',
      'add dinner',
      'add breakfast',
      'search',
      'custom',
      'prev',
    ]);
  });
}
