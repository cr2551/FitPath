# FitPath backup format (version 1)

A backup is one UTF-8 JSON file, named `fitpath-backup-YYYY-MM-DD.json`. It is
written by `ExportService` (`lib/features/settings/backup/export_service.dart`)
and read by the import feature (#41).

## Top level

```json
{
  "format": "fitpath-backup",
  "format_version": 1,
  "app_version": "1.0.0+1",
  "exported_at": "2026-11-04T18:20:00.000Z",
  "tables": { "app_settings": [ ... ], "user_profile": [ ... ], ... }
}
```

| Key | Meaning |
|---|---|
| `format` | Always `fitpath-backup`. Anything else is not a FitPath backup. |
| `format_version` | Layout version. Bumped on incompatible changes; an importer refuses versions it does not know. |
| `app_version` | `version+build` of the app that wrote the file (informational). |
| `exported_at` | When the file was written, UTC, ISO 8601. |
| `tables` | One array of rows per table (below). |

## Tables

Keys are the SQLite table names, listed in an order that satisfies the
foreign keys when rows are inserted front to back:

| Key | Rows |
|---|---|
| `app_settings` | The single settings row (units, theme). |
| `user_profile` | The profile (0 or 1 row). |
| `fitness_goals` | All goals, including inactive ones. |
| `weight_entries` | Every weight entry. |
| `nutrition_targets` | Target history (each row applies from `effectiveFrom`). |
| `food_items` | Custom foods, cached Open Food Facts foods, and the bundled foods that a diary entry references. |
| `food_entries` | The diary, with each entry's nutrient snapshot. |
| `exercises` | Custom exercises (including soft-deleted ones), and the bundled exercises that a session uses. |
| `workout_sessions` | Every session, any status. |
| `workout_exercises` | Exercises in sessions, with the name snapshot and order. |
| `workout_sets` | Sets. |
| `dashboard_cards` | The Home layout. |

`app_metadata` (onboarding flag, data format version) is technical state and
is not exported.

## Rows

Each row is the Drift `toJson` of the table's data class:

- **Keys** are the Dart field names in camelCase (`foodItemId`, `consumedAt`).
- **Ids** are kept as they are in the database, so every relationship
  (`foodItemId`, `sessionId`, `workoutExerciseId`, `exerciseId`) still points
  at the right row after a restore.
- **Dates and times** are ISO 8601 strings. `localDate` and `effectiveFrom`
  are `yyyy-MM-dd` text.
- **Enums** are their names (`"breakfast"`, `"per100g"`, `"completed"`).
- **Unknown values** are `null`, never `0`.
- **Units:** values are stored metric, as in the database (kg, cm, g, ml).

## Privacy

The database holds no passwords, tokens or API keys, so a backup contains
none. It does contain personal health data (weight, age, diary), so keep the
file somewhere private.

## Restoring

`BackupValidator` (`lib/features/settings/backup/backup_validator.dart`)
checks the whole file before anything changes:

- `format` is `fitpath-backup`, and `format_version` is one this app knows
  (a newer version asks the user to update the app);
- every table is present and every row parses into its data class (types and
  required fields);
- ids are unique per table and every reference (`foodItemId`, `sessionId`,
  `exerciseId`, `workoutExerciseId`) points at a row in the file.

`ImportService` then replaces all user data in one transaction: user rows
are deleted, the backup's rows are inserted with their ids, and bundled
foods and exercises the backup references are written back under their ids.
Any failure rolls the whole restore back. A restored install is marked as
onboarded.
