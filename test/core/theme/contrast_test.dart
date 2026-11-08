import 'package:fitpath/core/theme/fit_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 contrast ratio of two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, c) in [
    ('light', FitColors.light),
    ('dark', FitColors.dark),
  ]) {
    group('$name theme meets WCAG AA', () {
      // Body and label text: 4.5:1 on every background it is drawn on.
      for (final (bg, bgName) in [
        (c.surface, 'surface'),
        (c.background, 'background'),
        (c.subtle, 'subtle'),
      ]) {
        test('ink and muted ink on $bgName', () {
          expect(contrast(c.ink, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.inkMuted, bg), greaterThanOrEqualTo(4.5));
        });
      }

      test('accent buttons and status text', () {
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        expect(contrast(c.accent, c.surface), greaterThanOrEqualTo(4.5));
        for (final status in [c.success, c.warning, c.error]) {
          expect(contrast(status, c.surface), greaterThanOrEqualTo(4.5));
        }
      });

      // Macro colors are fills, never text, and always sit next to a text
      // label with the value, so they are not checked here.
    });
  }
}
