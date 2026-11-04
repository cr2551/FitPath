import 'package:fitpath/core/utils/formatters.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown values render as an em dash, never zero', () {
    expect(Formatters.weight(null, UnitSystem.metric), '—');
    expect(Formatters.height(null, UnitSystem.imperial), '—');
    expect(Formatters.energy(null), '—');
    expect(Formatters.grams(null), '—');
    expect(Formatters.integer(null), '—');
    expect(Formatters.percent(null), '—');
  });

  test('weight', () {
    expect(Formatters.weight(74.2, UnitSystem.metric), '74.2 kg');
    expect(Formatters.weight(80, UnitSystem.imperial), '176.4 lb');
    expect(
      Formatters.weight(1234.56, UnitSystem.metric, decimals: 0),
      '1,235 kg',
    );
  });

  test('height', () {
    expect(Formatters.height(178, UnitSystem.metric), '178 cm');
    expect(Formatters.height(178, UnitSystem.imperial), '5′ 10″');
  });

  test('energy and integers use thousands separators', () {
    expect(Formatters.energy(1640), '1,640 kcal');
    expect(Formatters.energy(2099.6), '2,100 kcal');
    expect(Formatters.integer(12345), '12,345');
  });

  test('grams keep a decimal only for small fractional amounts', () {
    expect(Formatters.grams(110), '110 g');
    expect(Formatters.grams(110.4), '110 g');
    expect(Formatters.grams(0.5), '0.5 g');
    expect(Formatters.grams(3), '3 g');
  });

  test('percent', () {
    expect(Formatters.percent(0.2688), '27%');
    expect(Formatters.percent(1), '100%');
  });
}
