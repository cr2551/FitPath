import 'package:intl/intl.dart';

import '../../shared/models/enums.dart';
import 'units.dart';

/// Display formatting. Unknown values (null) render as [unknownValue], never
/// as zero, so missing data is not mistaken for a measurement.
abstract final class Formatters {
  static const String unknownValue = '—';

  static final NumberFormat _integer = NumberFormat('#,##0', 'en');

  static String _decimal(num value, int decimals) => NumberFormat(
    decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}',
    'en',
  ).format(value);

  /// `1,640`
  static String integer(num? value) =>
      value == null ? unknownValue : _integer.format(value.round());

  /// `74.2 kg` or `163.6 lb`.
  static String weight(double? kg, UnitSystem system, {int decimals = 1}) {
    if (kg == null) return unknownValue;
    final value = Units.weightForDisplay(kg, system);
    return '${_decimal(value, decimals)} ${Units.weightUnit(system)}';
  }

  /// `178 cm` or `5′ 10″`.
  static String height(double? cm, UnitSystem system) {
    if (cm == null) return unknownValue;
    if (system == UnitSystem.metric) return '${_decimal(cm, 0)} cm';
    final ft = Units.cmToFeetInches(cm);
    return '${ft.feet}′ ${ft.inches.round()}″';
  }

  /// `1,640 kcal`
  static String energy(num? kcal) =>
      kcal == null ? unknownValue : '${integer(kcal)} kcal';

  /// `110 g`, or `0.5 g` for small amounts.
  static String grams(double? g) {
    if (g == null) return unknownValue;
    return g < 10 && g != g.roundToDouble()
        ? '${_decimal(g, 1)} g'
        : '${integer(g)} g';
  }

  /// `27%` from a 0-1 share.
  static String percent(double? share) =>
      share == null ? unknownValue : '${(share * 100).round()}%';
}
