import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';

/// The time range picked on the Progress tab, shared by the Weight,
/// Nutrition and Workouts tabs.
final progressRangeProvider = NotifierProvider<ProgressRange, RangePreset>(
  ProgressRange.new,
);

class ProgressRange extends Notifier<RangePreset> {
  @override
  RangePreset build() => RangePreset.days30;

  void select(RangePreset preset) => state = preset;
}
