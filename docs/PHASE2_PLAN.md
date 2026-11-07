# FitPath Phase 2 plan

Phase 2 has two parts:

1. Finish and ship the MVP (v1.0).
2. Build the spec's **Priority 2** features (v1.1): personal records and 1RM estimates, monthly workout counts and streaks, the what-if fitness calculator, weekly reports, recipes, recipe recommendations and ingredient substitutions.

Priority 3 work (AI suggestions, natural-language and image food logging, barcode scanning, Health Connect, cloud sync) stays out of scope.

The way of working is the same as [MVP_PLAN.md](MVP_PLAN.md): one issue per branch per PR, waves, owned files, the container/view split, and the CLAUDE.md style rules.

## Where we are

- Waves 1-7 of the MVP are merged.
- A smoke test of the app on 5 Nov found 6 problems, all fixed in #96-#101.
- Still open: [#45](https://github.com/cr2551/FitPath/issues/45) REL-3 (integration tests; `integration_test/` is still empty) and [#46](https://github.com/cr2551/FitPath/issues/46) REL-4 (accessibility and polish pass).
- The database is at **schema v1** and the backup is at **format v1**.

Priority 2 needs only one schema change: recipes. Everything else is derived from data the app already stores (spec section 10, "Priority 2 data readiness"):

| Feature | Built from |
|---|---|
| Personal records, 1RM | `workout_sets` (load, reps) + `exercises.is_bodyweight` |
| Monthly counts, streaks | completed `workout_sessions` + `user_profile.training_frequency_per_week` |
| What-if calculator | profile, goals, targets, `weight_entries` |
| Weekly reports | `food_entries`, `nutrition_targets`, sessions, weights |
| Recipes, recommendations, substitutions | **new tables** (schema v2) + bundled assets |

## Milestones

| Milestone | Content | Exit condition |
|---|---|---|
| **M9 MVP release (v1.0)** | REL-3, REL-4, release build on devices, internal testing track | All 10 MVP acceptance criteria covered by integration tests; release build tested on a small and a large Android phone with large fonts; uploaded to Play internal testing |
| **M10 Training insights** | PRs, 1RM, monthly counts, streaks | PRs and 1RM appear in session detail and exercise history; streak shown on Progress and as a dashboard card |
| **M11 Planning and reports** | What-if calculator, weekly reports | Projection is labelled as an estimate, matches hand calculations in tests, and can be applied as targets; a weekly report exists for any past week |
| **M12 Recipes** | Schema v2, recipe builder, recommendations, substitutions, backup v2 | A recipe can be built, logged and restored from a backup; v1 databases and v1 backups upgrade cleanly |
| **M13 v1.1 release** | Phase 2 integration tests, polish, store update | Same bar as M9 for the new features |

M9 runs at the same time as the Phase 2 foundation (wave P0). Phase 2 features only reach users in v1.1.

## Issues

Keys use the `P2-` prefix. Sizes: S ≈ 1-2 days, M ≈ 3-4 days, L ≈ 1 week.

### Wave P0: release v1.0 and Phase 2 foundation

| Issue | Title | Lane | Size | Blocked by |
|---|---|---|---|---|
| [#45](https://github.com/cr2551/FitPath/issues/45) REL-3 | End-to-end integration tests for the MVP acceptance criteria | Release | L | - |
| [#46](https://github.com/cr2551/FitPath/issues/46) REL-4 | Accessibility, responsiveness and error-state polish pass | Release | M | - |
| [#102](https://github.com/cr2551/FitPath/issues/102) P2-REL-1 | Release v1.0: device test matrix, Play internal track, store assets check | Release | S | #45, #46 |
| [#103](https://github.com/cr2551/FitPath/issues/103) P2-CORE-1 | Phase 2 route table and placeholder screens (same pattern as CORE-3) | Core | S | - |
| [#104](https://github.com/cr2551/FitPath/issues/104) P2-CORE-2 | Phase 2 enum values: card types `personalRecords`, `streak`, `weeklyReport` (with catalog entries) and `FoodSource.recipe` | Core | S | - |
| [#105](https://github.com/cr2551/FitPath/issues/105) P2-CALC-1 | Strength stats (pure Dart): 1RM estimate, PR detection per exercise | B: Workouts | S | - |
| [#106](https://github.com/cr2551/FitPath/issues/106) P2-CALC-2 | Activity stats (pure Dart): monthly session counts, weekly streak | B: Workouts | S | - |
| [#107](https://github.com/cr2551/FitPath/issues/107) P2-CALC-3 | Weight projection (pure Dart): what-if energy-balance model with guardrails | C: Profile | M | - |
| [#108](https://github.com/cr2551/FitPath/issues/108) P2-CALC-4 | Weekly report aggregation (pure Dart): nutrition, training, weight vs previous week | D: Progress | S | - |
| [#109](https://github.com/cr2551/FitPath/issues/109) P2-DATA-1 | Schema v2: `recipes`, `recipe_ingredients`; migration + migration test | A: Nutrition | M | #104 |

P2-CORE-1 and P2-CORE-2 freeze the shared files (`routes.dart`, `app_router.dart`, `enums.dart`, `card_catalog.dart`) again before feature work starts. P2-DATA-1 is the only change to `app_database.dart`. It waits for P2-CORE-2 only for the `FoodSource.recipe` value.

### Wave P1: feature screens

| Issue | Title | Lane | Size | Blocked by |
|---|---|---|---|---|
| [#110](https://github.com/cr2551/FitPath/issues/110) P2-WO-1 | Exercise history screen: PR list, estimated-1RM chart; "New PR" marks in session detail | B | M | #103, #105 |
| [#111](https://github.com/cr2551/FitPath/issues/111) P2-WO-2 | Monthly workout counts and streak on Progress › Workouts | B | S | #106 |
| [#112](https://github.com/cr2551/FitPath/issues/112) P2-PLAN-1 | What-if calculator screen: inputs, projected weight chart (dashed), apply as targets | C | M | #103, #107 |
| [#113](https://github.com/cr2551/FitPath/issues/113) P2-REP-1 | Weekly report screen with week picker and previous-week comparison | D | M | #103, #108 |
| [#114](https://github.com/cr2551/FitPath/issues/114) P2-NUT-1 | Recipe builder: ingredients from the catalog, servings, per-serving nutrition; log a recipe | A | M | #103, #109 |
| [#115](https://github.com/cr2551/FitPath/issues/115) P2-BAK-1 | Backup format v2 (recipes); import still accepts v1 | D | S | #109 |

### Wave P2: recommendations and dashboard

| Issue | Title | Lane | Size | Blocked by |
|---|---|---|---|---|
| [#116](https://github.com/cr2551/FitPath/issues/116) P2-DATA-2 | Bundled recipe and substitution catalogs: import UniTools recipes and Wikibooks substitutions, map ingredients, attribution, seeding | A | M | #109 |
| [#118](https://github.com/cr2551/FitPath/issues/118) P2-NUT-2 | Recipe recommendations: rank bundled and own recipes by fit to the day's remaining calories and macros | A | M | #114, #116 |
| [#119](https://github.com/cr2551/FitPath/issues/119) P2-NUT-3 | Ingredient substitutions in the recipe builder with kcal/macro difference | A | S | #114, #116 |
| [#117](https://github.com/cr2551/FitPath/issues/117) P2-DASH-1 | Dashboard cards: personal records, streak, last week's report | D | M | #104, #105, #106, #108 |

### Wave P3: release v1.1

| Issue | Title | Lane | Size | Blocked by |
|---|---|---|---|---|
| [#120](https://github.com/cr2551/FitPath/issues/120) P2-REL-2 | Integration tests for Phase 2 (including a v1 → v2 database upgrade and a v1 backup restore) | Release | M | all P1/P2 issues |
| [#121](https://github.com/cr2551/FitPath/issues/121) P2-REL-3 | Polish pass and v1.1 store update | Release | S | #120 |

**Critical path:** #104 P2-CORE-2 → #109 P2-DATA-1 → #114 P2-NUT-1 and #116 P2-DATA-2 (in parallel) → #118 P2-NUT-2 → #120 P2-REL-2 → #121 P2-REL-3.

Recipes are the longest lane and the only schema change, so start #104 and #109 first.

## Design notes per feature

**Personal records and 1RM (P2-CALC-1, P2-WO-1)**
- The PRs per exercise are:
  - heaviest load;
  - most reps at a given load;
  - best set volume (load × reps);
  - best estimated 1RM.
- 1RM is shown with **both formulas side by side**, labelled as estimates:
  - Epley: $1\text{RM} = w\left(1 + \tfrac{r}{30}\right)$
  - Brzycki: $1\text{RM} = w \cdot \tfrac{36}{37 - r}$
- 1RM is calculated only for loaded resistance sets with 1-10 reps: both formulas lose accuracy above 10 reps, and Brzycki breaks down as $r$ approaches 37. A single rep is the 1RM itself.
- Bodyweight exercises (`is_bodyweight`) get a reps PR only (spec section 10: volume is not comparable for every exercise type).
- The "best estimated 1RM" PR is ranked by Epley, so there is one ranking.
- Only completed sessions count.

**Streaks and monthly counts (P2-CALC-2, P2-WO-2)**
- A week counts toward the streak when it has **at least one completed workout**. The weekly training target in the profile is not used.
- The current, unfinished week never breaks a streak: it extends the streak once it has a workout.
- Monthly counts are completed sessions per calendar month. The week starts on Sunday, matching the date strip.

**What-if calculator (P2-CALC-3, P2-PLAN-1)**
- Inputs: daily calories, activity level, target weight.
- The projection is day by day and **recalculates energy needs every day**: BMR and TDEE come from that day's projected weight (Mifflin-St Jeor, CALC-1). The day's balance $\text{intake} - \text{TDEE}$ changes weight at about 7,700 kcal per kg. So the projection slows as the user approaches the target, instead of following a straight line.
- The result is a projected weight curve and an estimated date for reaching the target.
- **Guardrails:**
  - reuse the CALC-1 calorie floors;
  - flag any pace over 1% of body weight a week;
  - cap the horizon at 1 year;
  - always show the result as an approximation with the estimate badge and the existing disclaimer wording.
- "Apply" saves new nutrition targets (source `user`, effective today). It never changes past targets.

**Weekly reports (P2-CALC-4, P2-REP-1)**
- **Nutrition:** days logged, average calories against the targets in effect each day, and macro adherence.
- **Training:** sessions, total volume, new PRs.
- **Weight:** change since the previous week.
- Each figure is compared with the previous week, and missing data is reported as missing, not as zero.
- No notifications in v1.1: they would need a permission and background scheduling.

**Recipes (P2-DATA-1, P2-NUT-1)**
- A recipe is stored as a `food_items` row (`source = recipe`, basis per serving), so search, logging, snapshots and the diary work unchanged.
- Its ingredients go in `recipe_ingredients` (food id, quantity, unit). Nutrition is computed from the ingredients with the existing `NutritionMath` and cached on the food row whenever the recipe is saved.
- Editing a recipe never changes logged entries, because entries keep their snapshots.

**Recommendations and substitutions (P2-DATA-2, P2-NUT-2, P2-NUT-3)**
- Both are **rule-based**, not AI (AI is Priority 3).
- Recommendations rank recipes by how well one serving fits the day's remaining calories and macros, with the goal as a tie-breaker.
- Substitutions come from a bundled table (e.g. sour cream → Greek yogurt) and show the calorie and macro difference, computed from our own catalog, before the user accepts.
- The content comes from openly licensed datasets; see "Recipe and substitution data" below.

## Recipe and substitution data (licence check, 7 Nov 2026)

Candidates were traced back to their original source; a licence label on a mirror (e.g. Kaggle) was not taken at face value.

| Dataset | Licence | Verdict |
|---|---|---|
| **UniTools World Recipes** v2.0.0 ([repo](https://github.com/farcrak/unitools-recipes), [data page](https://theunitools.com/en/data)): 501 recipes from 127 countries; ingredients with id, quantity and unit (mostly grams), servings, per-serving calories/protein/fat/carbs | **CC BY-SA 4.0**, full licence text in the repo's `LICENSE`; the README says commercial use is allowed | **Use for recipes.** |
| **Wikibooks Cookbook: Substitutions** ([page](https://en.wikibooks.org/wiki/Cookbook:Substitutions)) | **CC BY-SA 4.0** (Wikimedia text licence since June 2023; also GFDL for most pages, per [Wikibooks:COPY](https://en.wikibooks.org/wiki/Wikibooks:COPY)) | **Use for substitutions.** |
| USDA MyPlate Kitchen recipes | US federal works are public domain (17 USC 105), but some recipes were contributed by non-federal partners, the official site was retired on 7 Jan 2026, and the surviving copy (myplate.food) is a third-party site with its own terms for its additions | Possible later supplement, limited to recipes authored by federal agencies and taken from an official copy. Not needed now. |
| "Better Recipes for a Better Life" (Kaggle) | Labelled CC0 by the uploader, but its source repository (agm316/Food-Your-Way) states no licence, and the recipe data appears to be collected from a recipe website | **Rejected**: the CC0 label cannot be trusted. |
| RecipeNLG, Recipe1M, "Recipe Dataset (over 2M)", IndicRecipeNutri | Non-commercial (e.g. CC BY-NC-SA 4.0) | **Rejected**: not open for commercial use. |

**What CC BY-SA 4.0 requires of us**
- **Attribution:** credit "UniTools — theunitools.com" and "Wikibooks Cookbook contributors", with a link and the licence name. Show the credit on the About screen, on bundled recipes and substitutions, and in `docs/third-party-data.md`.
- **Share-alike:** our bundled `recipes_*.json` and `substitutions_*.json` are adaptations, so they are released under CC BY-SA 4.0. Mark this in `assets/data/README.md` and keep them as separate data files. The app's own code is not affected: bundling a separate dataset is an aggregation, not an adaptation.
- **Changes:** note that we changed the data (subset, ingredient mapping, unit conversion).
- **Photos:** not bundled. UniTools photos carry their own Wikimedia Commons licences.
- **Data quality:** UniTools nutrition is computed from ingredients and the dataset has a single maintainer. Show it as an estimate, keep the dataset's version, and spot-check a sample against our USDA-based catalog in P2-DATA-2.
- This is a reading of the licences, not legal advice. Have someone with legal background confirm it before the v1.1 release (part of P2-REL-3).

## Carry-overs from the smoke test

- Dropdown menus are flat now, but their bottom edge is faint over white inputs. A small shared dropdown widget with a 1 px border would fix it; fold this into REL-4.
- First launch now seeds the catalogs before the first frame. Measure this on a low-end phone in P2-REL-1.

## Decisions (7 Nov 2026)

1. **Streak rule:** a week counts after any single completed workout.
2. **1RM:** show Epley and Brzycki side by side, for loaded sets of 1-10 reps.
3. **What-if model:** recalculate BMR/TDEE from the projected weight every day.
4. **Recipe content:** use openly licensed datasets: UniTools World Recipes and Wikibooks Cookbook substitutions, both CC BY-SA 4.0 (see above).
5. **Spec deferrals:** no non-strength exercise types and no Android device backup in Phase 2.
