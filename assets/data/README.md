# Bundled catalogs

Seeded into the local database on first launch (`lib/core/database/seed/`), so logging works offline from day one.

## `foods_starter.json`

About 150 common generic foods: fruits, vegetables, grains, meat and fish, eggs, legumes, dairy and alternatives, nuts and fats, snacks, common dishes, drinks and condiments.

- **Basis:** values are per 100 g (`per100g`) or per 100 ml for liquids (`per100ml`). Grams and millilitres are never mixed.
- **Fields:**
  - Energy: `kcal`.
  - Macros and other nutrients: `proteinG`, `carbsG`, `fatG`, `fiberG`, `sugarG`, `sodiumMg`.
  - `null` means unknown, never zero.
  - Each food also has a typical `serving` (size, unit and a description such as "1 medium").
- **Source:** values are based on **USDA FoodData Central** (SR Legacy and Survey data, public domain, <https://fdc.nal.usda.gov>), rounded. Mixed dishes ("Pizza, cheese", "Bean burrito", ...) and "Whey protein powder" are typical averages and vary by recipe or brand.
- **Checks:** `test/core/database/seed/food_seed_test.dart` validates every entry. The label calories must agree with protein × 4 + carbs × 4 + fat × 9 to within 15%; alcoholic drinks are excepted.
- **Before release:** spot-check values against FoodData Central and update the About screen attribution (#43).

To change the list, edit the JSON (keep `"version": 1` and unique names) and run the tests. The catalog is inserted only when the database is created, so existing installs need a migration to receive new foods.

## `exercises_starter.json`

About 80 common strength exercises, each with a `muscleGroup` (chest, back, legs, shoulders, arms, core, full body), `equipment` (barbell, dumbbell, machine, cable, kettlebell, bodyweight, other) and an `isBodyweight` flag. Bodyweight exercises are compared by reps, not volume.

Seeded by `seedExercises` and validated by `test/core/database/seed/exercise_seed_test.dart`. Users add their own exercises as custom exercises; history stores each exercise's name as a snapshot, so renaming or deleting one never changes past workouts.

## `recipes_bundled.json`

An English-only, offline subset of **UniTools World Recipes 2.0.0** (retrieved 20 November 2026 from <https://theunitools.com/en/data>). The source dataset is **CC BY-SA 4.0**; credit: **UniTools — theunitools.com**. Recipe nutrition is the source's computed per-serving estimate, not laboratory analysis. Photos are not bundled.

The data is an adaptation released under **CC BY-SA 4.0**. Changes: recipes without enough mapped starter-food ingredients are omitted; mapped ingredient ids use FitPath's generic USDA-based foods; unsupported ingredients and units are omitted; only English names and no photos are retained. Rebuild it with:

```bash
dart run tool/import_unitools_recipes.dart <path-to-unitools-recipes-v1.json>
```

The seeder records the source version and uses the source recipe slug as a stable id, so it is safe to run again on an existing install.

## `substitutions.json`

A curated adaptation of **Wikibooks Cookbook contributors**, [Cookbook:Substitutions](https://en.wikibooks.org/wiki/Cookbook:Substitutions), revision `4528639`, retrieved 20 November 2026. It is **CC BY-SA 4.0** and is released under the same licence. Entries are limited to ingredients that map to FitPath's starter catalog; their ratios were normalized for display and each change is stated in the file metadata.
