import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/dates.dart';
import '../data/local/food_repository.dart';
import '../domain/nutrition_math.dart';

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => FoodRepository(ref.watch(appDatabaseProvider).foodDao),
);

/// Diary entries of one day, keyed by local date key (yyyy-MM-dd).
final diaryEntriesProvider = StreamProvider.family<List<FoodEntry>, String>(
  (ref, dateKey) => ref
      .watch(foodRepositoryProvider)
      .watchDay(Dates.fromLocalDateKey(dateKey)),
);

/// Totals, per-meal totals and the macro calorie split of one day.
final dailySummaryProvider =
    StreamProvider.family<DailyNutritionSummary, String>(
      (ref, dateKey) => ref
          .watch(foodRepositoryProvider)
          .watchDailySummary(Dates.fromLocalDateKey(dateKey)),
    );

/// Daily totals for a progress range, keyed by local date key.
final dailyTotalsProvider =
    StreamProvider.family<Map<String, NutrientTotals>, RangePreset>(
      (ref, preset) => ref
          .watch(foodRepositoryProvider)
          .watchDailyTotals(Dates.rangeFor(preset, DateTime.now())),
    );
