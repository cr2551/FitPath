import 'dart:math' as math;

import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/core/theme/app_typography.dart';
import 'package:fitpath/core/theme/fit_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance contrast ratio.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = {'light': AppTheme.light, 'dark': AppTheme.dark};

  themes.forEach((name, theme) {
    final c = theme.extension<FitColors>()!;

    group('$name theme', () {
      test('registers the FitColors and FitTextStyles extensions', () {
        expect(theme.extension<FitTextStyles>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, c.background);
      });

      test('text contrast meets WCAG AA (4.5:1)', () {
        final pairs = {
          'ink on background': (c.ink, c.background),
          'ink on surface': (c.ink, c.surface),
          'ink on subtle': (c.ink, c.subtle),
          'muted on surface': (c.inkMuted, c.surface),
          'muted on background': (c.inkMuted, c.background),
          'on-accent on accent': (c.onAccent, c.accent),
          'surface on ink (filled button)': (c.surface, c.ink),
          'success on surface': (c.success, c.surface),
          'warning on surface': (c.warning, c.surface),
          'error on surface': (c.error, c.surface),
        };
        pairs.forEach((label, p) {
          expect(
            contrast(p.$1, p.$2),
            greaterThanOrEqualTo(4.5),
            reason: label,
          );
        });
      });

      test('no shadows: every component theme has elevation 0', () {
        expect(theme.cardTheme.elevation, 0);
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.navigationBarTheme.elevation, 0);
        expect(theme.dialogTheme.elevation, 0);
        expect(theme.bottomSheetTheme.elevation, 0);
        expect(theme.bottomSheetTheme.modalElevation, 0);
        expect(theme.snackBarTheme.elevation, 0);
        expect(theme.chipTheme.elevation, 0);
        expect(theme.filledButtonTheme.style!.elevation!.resolve({}), 0);
      });

      test('no radius above 8 px', () {
        double radius(ShapeBorder? s) {
          if (s is! RoundedRectangleBorder) return 0;
          final r = s.borderRadius.resolve(TextDirection.ltr);
          return [
            r.topLeft.x,
            r.topRight.x,
            r.bottomLeft.x,
            r.bottomRight.x,
          ].reduce(math.max);
        }

        final shapes = <String, ShapeBorder?>{
          'card': theme.cardTheme.shape,
          'dialog': theme.dialogTheme.shape,
          'sheet': theme.bottomSheetTheme.shape,
          'snackbar': theme.snackBarTheme.shape,
          'chip': theme.chipTheme.shape,
          'nav indicator': theme.navigationBarTheme.indicatorShape,
          'filled button': theme.filledButtonTheme.style!.shape!.resolve({}),
          'outlined button': theme.outlinedButtonTheme.style!.shape!.resolve(
            {},
          ),
          'segmented': theme.segmentedButtonTheme.style!.shape!.resolve({}),
        };
        shapes.forEach((label, s) {
          expect(s, isA<RoundedRectangleBorder>(), reason: label);
          expect(radius(s), lessThanOrEqualTo(8), reason: label);
        });
        expect(
          (theme.inputDecorationTheme.border! as OutlineInputBorder)
              .borderRadius
              .topLeft
              .x,
          lessThanOrEqualTo(8),
        );
      });

      test('uses the bundled fonts', () {
        expect(theme.textTheme.headlineMedium!.fontFamily, AppFonts.condensed);
        expect(theme.textTheme.displayLarge!.fontFamily, AppFonts.condensed);
        expect(theme.textTheme.bodyLarge!.fontFamily, AppFonts.body);
        expect(
          theme.textTheme.displayLarge!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      });
    });
  });

  testWidgets('sample components render in light and dark', (tester) async {
    for (final theme in themes.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Today')),
              body: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Calorie goal: 2,100 kcal',
                        style: context.textStyles.cardTitle,
                      ),
                    ),
                  ),
                  FilledButton(onPressed: () {}, child: const Text('START')),
                  FilledButton(
                    style: AppTheme.accentButton(context),
                    onPressed: () {},
                    child: const Text('LOG FOOD'),
                  ),
                  OutlinedButton(onPressed: () {}, child: const Text('CANCEL')),
                  const TextField(
                    decoration: InputDecoration(hintText: 'Search foods'),
                  ),
                  const Chip(label: Text('Legs')),
                  Container(height: 6, color: context.fitColors.protein),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('LOG FOOD'), findsOneWidget);
    }
  });

  test('a selected chip label contrasts with its ink fill', () {
    for (final (theme, c) in [
      (AppTheme.light, FitColors.light),
      (AppTheme.dark, FitColors.dark),
    ]) {
      // Mirrors how RawChip resolves its label: only the color, by state.
      final color = theme.chipTheme.labelStyle!.color;
      Color? resolve(Set<WidgetState> states) =>
          WidgetStateProperty.resolveAs<Color?>(color, states);
      expect(theme.chipTheme.selectedColor, c.ink);
      expect(resolve({WidgetState.selected}), c.surface);
      expect(resolve({}), c.ink);
    }
  });

  testWidgets('rendered chips: ink label, surface label when selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              FilterChip(label: const Text('Off'), onSelected: (_) {}),
              FilterChip(
                label: const Text('On'),
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(_chipLabelColor(tester, 'Off'), FitColors.light.ink);
    expect(_chipLabelColor(tester, 'On'), FitColors.light.surface);
  });

  test('popup menus are flat with a line border', () {
    final menu = AppTheme.light.popupMenuTheme;
    expect(menu.elevation, 0);
    expect(
      (menu.shape! as RoundedRectangleBorder).side.color,
      FitColors.light.line,
    );
  });
}

/// The label color a rendered [FilterChip] actually paints.
Color? _chipLabelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color ??
    DefaultTextStyle.of(tester.element(find.text(label))).style.color;
