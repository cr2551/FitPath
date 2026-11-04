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
