import '../../../../core/utils/units.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/strength_stats.dart';

/// "Heaviest load · 100 kg", "8 reps at 60 kg", "Most reps · 15".
String prRecordLabel(NewPr pr, UnitSystem units) {
  final unit = Units.weightUnit(units);
  String kg(double v) => Units.weightForDisplay(
    v,
    units,
  ).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  final s = pr.set;
  return switch (pr.kind) {
    PrKind.heaviestLoad => 'Heaviest load · ${kg(s.weightKg!)} $unit',
    PrKind.repsAtLoad => '${s.reps} reps at ${kg(s.weightKg!)} $unit',
    PrKind.setVolume => 'Best set volume · ${kg(s.volumeKg!)} $unit',
    PrKind.oneRepMax => 'Estimated 1RM · ${kg(s.oneRepMax!.epleyKg)} $unit',
    PrKind.mostReps => 'Most reps · ${s.reps}',
  };
}
