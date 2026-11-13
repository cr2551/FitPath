import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:fitpath/core/database/app_database.dart';
import 'package:fitpath/core/database/database_provider.dart';
import 'package:fitpath/core/theme/app_theme.dart';
import 'package:fitpath/features/dashboard/data/dashboard_repository.dart';
import 'package:fitpath/features/nutrition/data/local/food_repository.dart';
import 'package:fitpath/features/nutrition/domain/nutrients.dart';
import 'package:fitpath/features/nutrition/domain/nutrition_math.dart';
import 'package:fitpath/features/profile/data/profile_repository.dart';
import 'package:fitpath/features/settings/backup/backup_models.dart';
import 'package:fitpath/features/settings/backup/export_service.dart';
import 'package:fitpath/features/settings/presentation/backup_screen.dart';
import 'package:fitpath/shared/models/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

/// Fills every user table: profile, goal, weight, targets, a custom food,
/// a used and an unused bundled food, a diary entry, a custom exercise, a
/// used and an unused bundled exercise, a session with a set, a dashboard.
Future<void> _fill(AppDatabase db) async {
  final profile = ProfileRepository(db.profileDao);
  await profile.saveProfile(ageYears: 30, heightCm: 180, sex: Sex.female);
  await profile.setPrimaryGoal(GoalType.loseWeight, targetWeightKg: 70);
  await profile.logWeight(74.2);
  await profile.setTargets(calories: 2000, source: TargetSource.user);

  Future<int> bundledFood(String name) => db.foodDao.insertFood(
    FoodItemsCompanion.insert(
      name: name,
      referenceBasis: ReferenceBasis.per100g,
      source: FoodSource.bundled,
      kcal: const Value(100),
    ),
  );
  final usedBundled = await bundledFood('Apple');
  await bundledFood('Pear');
  final foods = FoodRepository(db.foodDao);
  await foods.createCustomFood(
    const FoodDetails(
      name: 'Granola',
      basis: ReferenceBasis.per100g,
      nutrients: Nutrients(kcal: 450),
    ),
  );
  await foods.logFood(
    foodId: usedBundled,
    quantity: 150,
    unit: QuantityUnit.gram,
    meal: MealType.snack,
  );

  Future<int> exercise(String name, {bool custom = false}) => db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: name,
          muscleGroup: 'legs',
          isCustom: Value(custom),
        ),
      );
  final squat = await exercise('Squat');
  await exercise('Lunge');
  await exercise('Sissy squat', custom: true);
  final session = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          startedAt: DateTime(2026, 11, 3, 18),
          completedAt: Value(DateTime(2026, 11, 3, 19)),
          status: WorkoutStatus.completed,
        ),
      );
  final we = await db
      .into(db.workoutExercises)
      .insert(
        WorkoutExercisesCompanion.insert(
          sessionId: session,
          exerciseId: squat,
          exerciseNameSnapshot: 'Squat',
          orderIndex: 0,
        ),
      );
  await db
      .into(db.workoutSets)
      .insert(
        WorkoutSetsCompanion.insert(
          workoutExerciseId: we,
          setNumber: 1,
          repetitions: const Value(5),
          weightKg: const Value(100),
          completed: const Value(true),
        ),
      );
  await DashboardRepository(db.dashboardDao).applyPreset(GoalType.loseWeight);
}

void main() {
  group('ExportService', () {
    late AppDatabase db;
    final at = DateTime.utc(2026, 11, 4, 18, 20);

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('exports every user-owned record with ids intact', () async {
      await _fill(db);
      final doc = await ExportService(
        db,
        clock: () => at,
      ).buildBackup(appVersion: '1.0.0+1');
      final t = doc.tables;

      expect(t.keys, BackupTables.all);
      expect(t[BackupTables.appSettings], hasLength(1));
      expect(t[BackupTables.userProfile], hasLength(1));
      expect(t[BackupTables.fitnessGoals], hasLength(1));
      expect(t[BackupTables.weightEntries], hasLength(1));
      expect(t[BackupTables.nutritionTargets], hasLength(1));
      expect(t[BackupTables.foodEntries], hasLength(1));
      expect(t[BackupTables.workoutSessions], hasLength(1));
      expect(t[BackupTables.workoutExercises], hasLength(1));
      expect(t[BackupTables.workoutSets], hasLength(1));
      expect(t[BackupTables.dashboardCards], hasLength(4));

      // Unused bundled catalog rows stay out; used ones and custom ones in.
      expect(t[BackupTables.foodItems]!.map((f) => f['name']), [
        'Apple',
        'Granola',
      ]);
      expect(t[BackupTables.exercises]!.map((e) => e['name']), [
        'Squat',
        'Sissy squat',
      ]);

      // Relationships point at exported ids.
      final entry = t[BackupTables.foodEntries]!.single;
      final apple = t[BackupTables.foodItems]!.first;
      expect(entry['foodItemId'], apple['id']);
      final set = t[BackupTables.workoutSets]!.single;
      expect(
        set['workoutExerciseId'],
        t[BackupTables.workoutExercises]!.single['id'],
      );
    });

    test('dates are ISO strings and enums are names', () async {
      await _fill(db);
      final doc = await ExportService(
        db,
        clock: () => at,
      ).buildBackup(appVersion: '1.0.0+1');
      final json =
          jsonDecode(ExportService.encode(doc)) as Map<String, dynamic>;

      expect(json['format'], 'fitpath-backup');
      expect(json['format_version'], 2);
      expect(json['app_version'], '1.0.0+1');
      expect(json['exported_at'], '2026-11-04T18:20:00.000Z');
      final tables = json['tables'] as Map<String, dynamic>;
      final session = (tables['workout_sessions'] as List).single as Map;
      expect(session['status'], 'completed');
      expect(
        DateTime.parse(session['startedAt'] as String),
        DateTime(2026, 11, 3, 18),
      );
      final entry = (tables['food_entries'] as List).single as Map;
      expect(entry['mealType'], 'snack');
      expect(entry['localDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('rows read back into the same data classes', () async {
      await _fill(db);
      final doc = await ExportService(db).buildBackup(appVersion: 'x');
      final rows = jsonDecode(ExportService.encode(doc))['tables'] as Map;
      final entry = FoodEntry.fromJson(
        (rows['food_entries'] as List).single as Map<String, dynamic>,
        serializer: backupSerializer,
      );
      expect(entry, (await db.select(db.foodEntries).get()).single);
      final session = WorkoutSession.fromJson(
        (rows['workout_sessions'] as List).single as Map<String, dynamic>,
        serializer: backupSerializer,
      );
      expect(session, (await db.select(db.workoutSessions).get()).single);
    });

    test('an empty database still makes a valid backup', () async {
      final doc = await ExportService(db).buildBackup(appVersion: 'x');
      expect(doc.tables[BackupTables.appSettings], hasLength(1));
      expect(doc.rowCount, 1);
      expect(doc.tables[BackupTables.recipes], isEmpty);
      expect(doc.tables[BackupTables.recipeIngredients], isEmpty);
    });

    test('file name', () {
      expect(
        ExportService.fileName(DateTime(2026, 3, 9)),
        'fitpath-backup-2026-03-09.json',
      );
    });
  });

  testWidgets('the screen shares and saves the backup file', (tester) async {
    final db = createTestDatabase();
    final delivery = _FakeDelivery();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
          backupDeliveryProvider.overrideWithValue(delivery),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const BackupScreen()),
      ),
    );

    await tester.tap(find.text('SHARE BACKUP'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(delivery.shared, hasLength(1));
    expect(delivery.shared.single.$1, startsWith('fitpath-backup-'));
    expect(
      (jsonDecode(delivery.shared.single.$2) as Map)['format'],
      'fitpath-backup',
    );

    await tester.tap(find.text('SAVE TO DEVICE'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(delivery.saved, hasLength(1));
    expect(find.textContaining('Saved fitpath-backup-'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(db.close);
  });
}

class _FakeDelivery extends BackupDelivery {
  final shared = <(String, String)>[];
  final saved = <(String, String)>[];

  @override
  Future<void> share(String fileName, String json) async =>
      shared.add((fileName, json));

  @override
  Future<bool> save(String fileName, String json) async {
    saved.add((fileName, json));
    return true;
  }
}
