import 'package:fitpath/core/utils/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local date key', () {
    test('formats with zero padding', () {
      expect(Dates.localDateKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });

    test('round trips', () {
      final d = DateTime(2026, 11, 3);
      expect(Dates.fromLocalDateKey(Dates.localDateKey(d)), d);
    });

    test('rejects invalid keys', () {
      for (final bad in ['2026-13-01', '2026-02-30', '26-01-01', 'today']) {
        expect(
          () => Dates.fromLocalDateKey(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('days', () {
    test('start of day and next day', () {
      final t = DateTime(2026, 12, 31, 18, 30);
      expect(Dates.startOfDay(t), DateTime(2026, 12, 31));
      expect(Dates.startOfNextDay(t), DateTime(2027));
    });

    test('addDays crosses months and years', () {
      expect(Dates.addDays(DateTime(2026, 2, 27), 2), DateTime(2026, 3, 1));
      expect(Dates.addDays(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
    });

    test('isSameDay ignores time', () {
      expect(
        Dates.isSameDay(DateTime(2026, 1, 1, 1), DateTime(2026, 1, 1, 23)),
        isTrue,
      );
      expect(
        Dates.isSameDay(DateTime(2026, 1, 1), DateTime(2026, 1, 2)),
        isFalse,
      );
    });
  });

  group('weeks', () {
    test('week starts on Sunday by default (Tue 3 Nov 2026 -> Sun 1 Nov)', () {
      expect(Dates.startOfWeek(DateTime(2026, 11, 3)), DateTime(2026, 11, 1));
      expect(Dates.startOfWeek(DateTime(2026, 11, 1)), DateTime(2026, 11, 1));
      expect(Dates.startOfWeek(DateTime(2026, 11, 7)), DateTime(2026, 11, 1));
    });

    test('Monday-first weeks', () {
      expect(
        Dates.startOfWeek(DateTime(2026, 11, 1), firstWeekday: DateTime.monday),
        DateTime(2026, 10, 26),
      );
    });

    test('weekOf returns seven consecutive days', () {
      final week = Dates.weekOf(DateTime(2026, 11, 3));
      expect(week, hasLength(7));
      expect(week.first, DateTime(2026, 11, 1));
      expect(week.last, DateTime(2026, 11, 7));
    });
  });

  group('range presets', () {
    final today = DateTime(2026, 11, 3, 15);

    test('day counts include today', () {
      expect(Dates.rangeFor(RangePreset.days7, today).days, 7);
      expect(Dates.rangeFor(RangePreset.days30, today).days, 30);
      expect(Dates.rangeFor(RangePreset.days90, today).days, 90);
      expect(Dates.rangeFor(RangePreset.year, today).days, 365);
    });

    test('1Y includes leap day without skipping the adjacent day', () {
      final leapDay = Dates.rangeFor(RangePreset.year, DateTime(2024, 2, 29));
      expect(leapDay.start, DateTime(2023, 3, 1));
      expect(leapDay.end, DateTime(2024, 3, 1));
      expect(leapDay.days, 366);

      final nextYear = Dates.rangeFor(RangePreset.year, DateTime(2025, 2, 28));
      expect(nextYear.start, DateTime(2024, 2, 29));
      expect(nextYear.end, DateTime(2025, 3, 1));
      expect(nextYear.days, 366);
    });

    test('7D covers 28 Oct to 3 Nov', () {
      final r = Dates.rangeFor(RangePreset.days7, today);
      expect(r.start, DateTime(2026, 10, 28));
      expect(r.end, DateTime(2026, 11, 4));
      expect(r.contains(DateTime(2026, 10, 28)), isTrue);
      expect(r.contains(DateTime(2026, 11, 3, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 10, 27, 23, 59)), isFalse);
      expect(r.contains(DateTime(2026, 11, 4)), isFalse);
    });

    test('All has no start', () {
      final r = Dates.rangeFor(RangePreset.all, today);
      expect(r.start, isNull);
      expect(r.days, isNull);
      expect(r.contains(DateTime(1990)), isTrue);
    });
  });
}
