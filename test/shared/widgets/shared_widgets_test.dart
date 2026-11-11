import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/theme/fit_colors.dart';
import 'package:fitpath/core/utils/dates.dart';
import 'package:fitpath/core/utils/units.dart';
import 'package:fitpath/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] on a 360 dp wide phone with the app theme.
Future<void> pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  ThemeData? theme,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 1600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final week = Dates.weekOf(DateTime(2026, 11, 3));

/// Every component, as a screen would compose them.
Widget gallery() => Builder(
  builder: (context) {
    final c = context.fitColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Today',
          subtitle: 'Lose weight · 72 kg by 1 Mar',
          leading: HeaderIconButton(
            icon: Icons.person_outline,
            tooltip: 'Profile',
            onPressed: () {},
          ),
          trailing: HeaderIconButton(
            icon: Icons.dashboard_outlined,
            tooltip: 'Edit dashboard',
            onPressed: () {},
          ),
        ),
        DateStrip(
          days: week,
          selected: DateTime(2026, 11, 3),
          today: DateTime(2026, 11, 3),
          daysWithEntries: const {'2026-11-01', '2026-11-03'},
          onSelected: (_) {},
        ),
        const SizedBox(height: 12),
        SectionCard(
          dividerBelowHeader: true,
          header: const CardHeader(
            icon: FitIcons.calories,
            title: 'Calorie goal: 2,100 kcal',
            subtitle: TextSpan(text: '460 kcal remaining today'),
          ),
          footer: const CardFooterStrip(
            items: [
              FooterItem(icon: Icons.restaurant, label: '3 meals logged'),
              FooterItem(
                icon: Icons.fitness_center,
                label: '2 workouts this week',
              ),
            ],
          ),
          child: Row(
            children: [
              MacroCalorieRing(
                eatenKcal: 1640,
                goalKcal: 2100,
                segments: [
                  RingSegment(color: c.protein, kcal: 440),
                  RingSegment(color: c.carbs, kcal: 720),
                  RingSegment(color: c.fat, kcal: 477),
                ],
                semanticsLabel: '1,640 of 2,100 calories eaten',
                center: const Text('1,640'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    MacroLegendRow(
                      icon: FitIcons.protein,
                      label: 'Protein',
                      color: c.protein,
                      consumedG: 110,
                      targetG: 140,
                      shareOfCalories: 0.27,
                    ),
                    MacroLegendRow(
                      icon: FitIcons.fat,
                      label: 'Fat',
                      color: c.fat,
                      consumedG: 53,
                      targetG: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const StatRow(
          items: [
            StatItem(label: 'Sessions', value: '3'),
            StatItem(label: 'Sets', value: '46'),
            StatItem(label: 'Volume', value: '9,840', unit: 'kg'),
          ],
        ),
        ListRow(
          title: 'Greek yogurt, plain',
          subtitle: '200 g · Bundled',
          value: '146',
          unit: 'kcal',
          onTap: () {},
        ),
        Row(
          children: [
            EstimateBadge(onTap: () {}),
            const SizedBox(width: 8),
            const FitProgressBar(fraction: 0.5, color: Colors.black).expanded(),
          ],
        ),
        EmptyState(
          message: 'Nothing logged yet',
          actionLabel: 'Add food',
          onAction: () {},
        ),
        ErrorState(message: 'Online search failed.', onRetry: () {}),
        UnitNumberField(
          label: 'Weight',
          unit: 'kg',
          range: PlausibleRanges.weightKg,
          onChanged: (_) {},
          initialValue: 74.2,
        ),
      ],
    );
  },
);

extension on Widget {
  Widget expanded() => Expanded(child: this);
}

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      testWidgets('all components render at ${scale}x text ($name)', (
        tester,
      ) async {
        await pump(tester, gallery(), textScale: scale, theme: theme);
        expect(tester.takeException(), isNull);
        expect(find.text('Today'), findsOneWidget);
      });
    }
  }

  testWidgets('date strip reports the tapped day', (tester) async {
    DateTime? picked;
    await pump(
      tester,
      DateStrip(days: week, selected: week[2], onSelected: (d) => picked = d),
    );

    await tester.tap(find.text('05'));
    expect(picked, DateTime(2026, 11, 5));
    expect(
      find.bySemanticsLabel(RegExp(r'Tuesday 3 November')),
      findsOneWidget,
    );
  });

  testWidgets('date strip marks today when another day is selected', (
    tester,
  ) async {
    await pump(
      tester,
      DateStrip(
        days: week,
        selected: week[5],
        today: week[2],
        onSelected: (_) {},
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^Tuesday 3 November, today')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r', today')), findsOneWidget);
  });

  testWidgets('macro legend shows "Set target" without a target', (
    tester,
  ) async {
    await pump(
      tester,
      const MacroLegendRow(
        icon: FitIcons.carbs,
        label: 'Carbs',
        color: Colors.green,
        consumedG: 180,
        targetG: null,
      ),
    );
    expect(find.textContaining('Set target'), findsOneWidget);
  });

  testWidgets('number field validates range and parses commas', (tester) async {
    final values = <double?>[];
    await pump(
      tester,
      UnitNumberField(
        label: 'Weight',
        unit: 'kg',
        range: PlausibleRanges.weightKg,
        onChanged: values.add,
      ),
    );

    await tester.enterText(find.byType(TextField), '74,5');
    await tester.pump();
    expect(values.last, 74.5);
    expect(find.textContaining('Enter a value'), findsNothing);

    await tester.enterText(find.byType(TextField), '500');
    await tester.pump();
    expect(values.last, isNull);
    expect(find.text('Enter a value between 30 and 350 kg'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('confirm dialog returns the choice', (tester) async {
    late BuildContext ctx;
    await pump(
      tester,
      Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    );

    final yes = showConfirmDialog(
      ctx,
      title: 'Reset all data?',
      message: 'This cannot be undone.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET'));
    expect(await yes, isTrue);

    final no = showConfirmDialog(ctx, title: 'Discard?', message: '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    expect(await no, isFalse);
  });

  testWidgets('async value view shows loading, error and data', (tester) async {
    Widget view(AsyncValue<String> v) =>
        AsyncValueView<String>(value: v, data: Text.new, onRetry: () {});

    // The spinner animates forever, so don't wait for it to settle.
    await pump(tester, view(const AsyncValue.loading()), settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pump(tester, view(const AsyncValue.error('x', StackTrace.empty)));
    expect(find.text('Retry'), findsOneWidget);

    await pump(tester, view(const AsyncValue.data('ready')));
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('ring exposes one summary for screen readers', (tester) async {
    await pump(
      tester,
      const MacroCalorieRing(
        eatenKcal: 1640,
        goalKcal: 2100,
        segments: [RingSegment(color: Colors.red, kcal: 1640)],
        semanticsLabel: '1,640 of 2,100 calories eaten',
        center: Text('1,640'),
      ),
    );
    expect(
      find.bySemanticsLabel('1,640 of 2,100 calories eaten'),
      findsOneWidget,
    );
  });
}
