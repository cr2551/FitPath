import 'package:drift/drift.dart';

import '../../../shared/models/enums.dart';

/// The single local profile (one per installation, so no user_id columns).
/// Current weight is NOT stored here: it is the latest [WeightEntries] row.
@DataClassName('UserProfileRow')
class UserProfile extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ageYears => integer().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get sex =>
      textEnum<Sex>().withDefault(Constant(Sex.unspecified.name))();
  TextColumn get activityLevel => textEnum<ActivityLevel>().nullable()();
  TextColumn get trainingExperience =>
      textEnum<TrainingExperience>().nullable()();
  IntColumn get trainingFrequencyPerWeek => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Goal history. Old goals are deactivated or completed, never overwritten.
@DataClassName('FitnessGoal')
class FitnessGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get goalType => textEnum<GoalType>()();
  BoolColumn get isPrimary => boolean()();
  RealColumn get targetWeightKg => real().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DataClassName('WeightEntry')
@TableIndex(name: 'weight_entries_recorded_at', columns: {#recordedAt})
class WeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weightKg => real()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get notes => text().nullable()();
}

/// Target history. The row with the latest [effectiveFrom] on or before a day
/// applies to that day, so past days keep their historical targets.
@DataClassName('NutritionTarget')
class NutritionTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get calories => integer()();
  RealColumn get proteinG => real().nullable()();
  RealColumn get carbsG => real().nullable()();
  RealColumn get fatG => real().nullable()();

  /// Local date key (yyyy-MM-dd), comparable with `food_entries.local_date`.
  TextColumn get effectiveFrom => text().withLength(min: 10, max: 10)();
  TextColumn get source => textEnum<TargetSource>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
