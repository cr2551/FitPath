/// Date helpers. All functions work on the device's local calendar date and
/// are DST-safe (they build dates from y/m/d instead of adding Durations).
abstract final class Dates {
  /// `2026-11-03`. Used as `food_entries.local_date` so a diary day never
  /// shifts when the device's time zone changes.
  static String localDateKey(DateTime dateTime) {
    final d = dateTime.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Inverse of [localDateKey]. Throws [FormatException] for invalid keys.
  static DateTime fromLocalDateKey(String key) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (match == null) throw FormatException('Invalid local date key', key);
    final date = DateTime(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
    if (localDateKey(date) != key) {
      throw FormatException('Invalid local date key', key);
    }
    return date;
  }

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Start of the following day (exclusive end of [d]'s day).
  static DateTime startOfNextDay(DateTime d) =>
      DateTime(d.year, d.month, d.day + 1);

  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// First day of the week containing [d]. Defaults to Sunday, matching the
  /// date strip in the design (Sun-Sat).
  static DateTime startOfWeek(
    DateTime d, {
    int firstWeekday = DateTime.sunday,
  }) {
    final offset = (d.weekday - firstWeekday) % 7;
    return DateTime(d.year, d.month, d.day - offset);
  }

  /// The seven days of the week containing [d], in order.
  static List<DateTime> weekOf(
    DateTime d, {
    int firstWeekday = DateTime.sunday,
  }) {
    final start = startOfWeek(d, firstWeekday: firstWeekday);
    return [for (var i = 0; i < 7; i++) addDays(start, i)];
  }

  /// The date range for a progress [preset], ending with [today] inclusive.
  static DateRange rangeFor(RangePreset preset, DateTime today) {
    final end = startOfNextDay(today);
    final start = switch (preset) {
      RangePreset.days7 => addDays(end, -7),
      RangePreset.days30 => addDays(end, -30),
      RangePreset.days90 => addDays(end, -90),
      RangePreset.year => _startOfYearRange(today),
      RangePreset.all => null,
    };
    return DateRange(start: start, end: end);
  }

  /// The day after the same calendar date last year. Clamp leap day to
  /// February 28 when the previous year has no February 29.
  static DateTime _startOfYearRange(DateTime today) {
    final previousYear = today.year - 1;
    final lastDayOfMonth = DateTime(previousYear, today.month + 1, 0).day;
    final anniversaryDay = today.day > lastDayOfMonth
        ? lastDayOfMonth
        : today.day;
    return DateTime(previousYear, today.month, anniversaryDay + 1);
  }
}

/// Progress range presets (7D / 30D / 90D / 1Y / All).
enum RangePreset { days7, days30, days90, year, all }

/// Half-open range `[start, end)`. A null [start] means "from the beginning".
class DateRange {
  const DateRange({required this.start, required this.end});

  final DateTime? start;
  final DateTime end;

  bool contains(DateTime t) =>
      t.isBefore(end) && (start == null || !t.isBefore(start!));

  /// Number of calendar days, or null for an open range.
  int? get days => start == null
      ? null
      : DateTime.utc(end.year, end.month, end.day)
            .difference(DateTime.utc(start!.year, start!.month, start!.day))
            .inDays;
}
