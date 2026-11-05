import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';

/// The day picked in the Home date strip (start of day, local time).
/// Date-aware dashboard cards read this.
final homeSelectedDateProvider = NotifierProvider<HomeSelectedDate, DateTime>(
  HomeSelectedDate.new,
);

class HomeSelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() => Dates.startOfDay(DateTime.now());

  void select(DateTime day) => state = Dates.startOfDay(day);
}
