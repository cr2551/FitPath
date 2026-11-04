import 'dart:math' as math;

import '../../shared/models/enums.dart';

/// Unit conversions. FitPath always STORES canonical metric values
/// (kg, cm, g, ml) and converts only for display and input.
abstract final class Units {
  static const double kgPerLb = 0.45359237;
  static const double cmPerInch = 2.54;
  static const int inchesPerFoot = 12;
  static const double gPerOz = 28.349523125;

  /// US customary fluid ounce.
  static const double mlPerFlOz = 29.5735295625;

  static double kgToLb(double kg) => kg / kgPerLb;
  static double lbToKg(double lb) => lb * kgPerLb;

  static double cmToInches(double cm) => cm / cmPerInch;
  static double inchesToCm(double inches) => inches * cmPerInch;

  /// Splits [cm] into whole feet and remaining inches, rounded to
  /// [inchDecimals] places. Never returns 12 inches (rolls over to a foot).
  static ({int feet, double inches}) cmToFeetInches(
    double cm, {
    int inchDecimals = 0,
  }) {
    final factor = math.pow(10, inchDecimals);
    final totalInches = (cmToInches(cm) * factor).round() / factor;
    final feet = totalInches ~/ inchesPerFoot;
    final inches = totalInches - feet * inchesPerFoot;
    return (feet: feet, inches: inches);
  }

  static double feetInchesToCm(int feet, double inches) =>
      inchesToCm(feet * inchesPerFoot + inches);

  static double gToOz(double g) => g / gPerOz;
  static double ozToG(double oz) => oz * gPerOz;

  static double mlToFlOz(double ml) => ml / mlPerFlOz;
  static double flOzToMl(double flOz) => flOz * mlPerFlOz;

  /// Body weight in the user's display unit.
  static double weightForDisplay(double kg, UnitSystem system) =>
      system == UnitSystem.metric ? kg : kgToLb(kg);

  /// Canonical kg from a value the user entered in [system] units.
  static double weightFromInput(double value, UnitSystem system) =>
      system == UnitSystem.metric ? value : lbToKg(value);

  static String weightUnit(UnitSystem system) =>
      system == UnitSystem.metric ? 'kg' : 'lb';

  /// Parses user-typed decimals, accepting either `.` or `,` as the decimal
  /// separator and surrounding whitespace. Returns null for anything else.
  static double? parseDecimal(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
    return double.tryParse(normalized);
  }
}

/// An inclusive numeric range.
class ValueRange {
  const ValueRange(this.min, this.max);

  final double min;
  final double max;

  bool contains(num value) => value >= min && value <= max;
}

/// Plausible input ranges shared by onboarding, settings and weight logging.
/// Values outside these ranges are rejected, never silently accepted.
abstract final class PlausibleRanges {
  static const ageYears = ValueRange(13, 100);
  static const heightCm = ValueRange(100, 250);
  static const weightKg = ValueRange(30, 350);
}
