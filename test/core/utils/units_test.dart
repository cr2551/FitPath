import 'package:fitpath/core/utils/units.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weight', () {
    test('kg <-> lb', () {
      expect(Units.kgToLb(1), closeTo(2.20462, 1e-5));
      expect(Units.lbToKg(1), 0.45359237);
    });

    test('round trip stays within 0.01 kg', () {
      for (var kg = 30.0; kg <= 350; kg += 0.7) {
        expect(Units.lbToKg(Units.kgToLb(kg)), closeTo(kg, 0.01));
      }
    });

    test('display and input follow the unit system', () {
      expect(Units.weightForDisplay(80, UnitSystem.metric), 80);
      expect(
        Units.weightForDisplay(80, UnitSystem.imperial),
        closeTo(176.37, 0.01),
      );
      expect(
        Units.weightFromInput(176.37, UnitSystem.imperial),
        closeTo(80, 0.01),
      );
      expect(Units.weightUnit(UnitSystem.imperial), 'lb');
    });
  });

  group('height', () {
    test('cm <-> inches', () {
      expect(Units.inchesToCm(1), 2.54);
      expect(Units.cmToInches(254), closeTo(100, 1e-9));
    });

    test('cm -> feet and inches', () {
      final r = Units.cmToFeetInches(178);
      expect(r.feet, 5);
      expect(r.inches, 10);
    });

    test('never returns 12 inches', () {
      // 182.8 cm = 71.97 in, rounds to 72 in = 6 ft 0 in.
      final r = Units.cmToFeetInches(182.8);
      expect(r.feet, 6);
      expect(r.inches, 0);
    });

    test('feet and inches -> cm round trip', () {
      expect(Units.feetInchesToCm(5, 10), closeTo(177.8, 1e-9));
      final r = Units.cmToFeetInches(Units.feetInchesToCm(6, 2));
      expect((r.feet, r.inches), (6, 2));
    });
  });

  group('food units', () {
    test('g <-> oz and ml <-> fl oz round trip', () {
      expect(Units.ozToG(Units.gToOz(100)), closeTo(100, 1e-9));
      expect(Units.flOzToMl(Units.mlToFlOz(250)), closeTo(250, 1e-9));
      expect(Units.gToOz(28.349523125), closeTo(1, 1e-12));
    });
  });

  group('parseDecimal', () {
    test('accepts dot, comma and whitespace', () {
      expect(Units.parseDecimal('74.2'), 74.2);
      expect(Units.parseDecimal(' 74,2 '), 74.2);
      expect(Units.parseDecimal('80'), 80);
    });

    test('rejects anything else', () {
      for (final bad in [
        '',
        ' ',
        'abc',
        '-5',
        '7.',
        '.5',
        '1e3',
        '74.2kg',
        '1,000.5',
      ]) {
        expect(Units.parseDecimal(bad), isNull, reason: bad);
      }
    });
  });

  group('plausible ranges', () {
    test('boundaries are inclusive', () {
      expect(PlausibleRanges.ageYears.contains(13), isTrue);
      expect(PlausibleRanges.ageYears.contains(12), isFalse);
      expect(PlausibleRanges.ageYears.contains(100), isTrue);
      expect(PlausibleRanges.heightCm.contains(99.9), isFalse);
      expect(PlausibleRanges.weightKg.contains(350), isTrue);
      expect(PlausibleRanges.weightKg.contains(350.1), isFalse);
    });
  });
}
