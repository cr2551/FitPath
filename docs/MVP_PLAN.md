# FitPath MVP implementation plan

Source of truth for scope: [`FitPath_Project_Specification.pdf`](../FitPath_Project_Specification.pdf). This plan breaks the MVP into GitHub issues that are tracked on the project board [**FitPath MVP**](https://github.com/users/cr2551/projects/5). Each issue lists what blocks it, what it blocks, which issues can be worked on in parallel, and which files it owns.

## Stack

Flutter (Android), Riverpod (no codegen), go_router, Drift + SQLite, Dio + Open Food Facts, fl_chart, json_serializable. Canonical units are stored (kg, cm, g, ml); display units are a preference only.

## How the work is split

1. **Foundation first (waves 1-2).** `CORE-1` is the only issue that can start on day one; it adds every package and the folder skeleton. Right after it merges, the shared foundation fans out into many independent issues (theme, router, database, utils, pure-Dart calculations, API client).
2. **Shared files are created once, up front.** The router (`CORE-3`) defines every route and a placeholder screen file for each; the database (`CORE-4`) defines every table and an empty DAO per feature. Feature work then only touches its own folder and replaces its own placeholder files.
3. **Four feature lanes** run in parallel, one per collaborator:

   - **Core**: Core / shared foundation (split between everyone in waves 1-2)
   - **A: Nutrition**: Lane A - Nutrition (catalog, Open Food Facts, diary, nutrition UI)
   - **B: Workouts**: Lane B - Workouts (exercise catalog, sessions, history)
   - **C: Onboarding & Settings**: Lane C - Onboarding, profile, goals, settings
   - **D: Dashboard, Progress & Backup**: Lane D - Home dashboard, progress charts, backup
   - **Release**: Release readiness (shared at the end)

4. **Release work** (`REL-1`, `REL-2`) can start early; the integration test suite and polish pass (`REL-3`, `REL-4`) close the MVP.

## Working agreement (avoiding merge conflicts)

- One issue = one branch (`<issue#>-short-name`) = one PR with `Closes #<issue#>`. Squash-merge into `main`.
- Start an issue only when every issue in its **Blocked by** list is merged.
- Only modify the paths listed under **Files / areas owned** in your issue. If you need a change in a file owned by another issue, comment on that issue or open a tiny separate PR.
- `pubspec.yaml` is owned by `CORE-1` (fonts section by `CORE-2`). Need a new package later? Open a small dedicated PR and merge it quickly.
- Generated files (`*.g.dart`) are **not committed**; run `dart run build_runner build -d` after pulling. CI does the same.
- `app_database.dart`, `app_router.dart` and `routes.dart` are frozen after `CORE-3`/`CORE-4`. Schema changes after v1 need a Drift migration and a migration test (NFR-04).
- Move your card on the board: Backlog -> Ready (deps merged) -> In progress -> In review -> Done.

## Waves

A wave is the earliest point an issue can start: wave N issues depend only on issues in earlier waves. Issues in the same wave never depend on each other and own different files, so they can be done in parallel.

### Wave 1

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#1](https://github.com/cr2551/FitPath/issues/1) | CORE-1 | Project setup: dependencies, lint rules, folder structure, shared enums and CI | Core | M | - |

### Wave 2

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#2](https://github.com/cr2551/FitPath/issues/2) | CORE-2 | Theme and design tokens (warm editorial look from the reference design) | Core | S | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#3](https://github.com/cr2551/FitPath/issues/3) | CORE-3 | App shell and navigation: go_router, bottom navigation, full route table with placeholder screens | Core | M | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#4](https://github.com/cr2551/FitPath/issues/4) | CORE-4 | Drift database v1: full MVP schema, foreign keys, migrations, DAO stubs and test helper | Core | L | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#5](https://github.com/cr2551/FitPath/issues/5) | CORE-5 | Unit conversion, formatting and date utilities (canonical metric storage) | Core | S | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#7](https://github.com/cr2551/FitPath/issues/7) | CALC-1 | Metabolic estimates service: BMI, BMR, TDEE, calorie and macro target suggestions | C: Onboarding & Settings | M | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#8](https://github.com/cr2551/FitPath/issues/8) | CALC-2 | Nutrition math: nutrient scaling by reference basis, daily totals, remaining vs over-target | A: Nutrition | S | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#9](https://github.com/cr2551/FitPath/issues/9) | CALC-3 | Workout math: set and session volume, best sets, per-exercise progression comparison | B: Workouts | S | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#13](https://github.com/cr2551/FitPath/issues/13) | DATA-4 | Open Food Facts API client (Dio) with offline/error handling | A: Nutrition | M | [#1](https://github.com/cr2551/FitPath/issues/1) |
| [#44](https://github.com/cr2551/FitPath/issues/44) | REL-2 | Android release configuration: app name, launcher icon, signing, versioning, store listing assets | Release | M | [#1](https://github.com/cr2551/FitPath/issues/1) |

### Wave 3

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#6](https://github.com/cr2551/FitPath/issues/6) | CORE-6 | Shared UI components: async/empty/error states, numeric unit input, date strip, dialogs, estimate badge | Core | M | [#2](https://github.com/cr2551/FitPath/issues/2) |
| [#10](https://github.com/cr2551/FitPath/issues/10) | DATA-1 | Profile repository: profile, goal history, weight entries, nutrition targets, settings, metadata | C: Onboarding & Settings | M | [#4](https://github.com/cr2551/FitPath/issues/4) |
| [#11](https://github.com/cr2551/FitPath/issues/11) | DATA-2 | Food catalog and diary repository with nutrient snapshots | A: Nutrition | M | [#4](https://github.com/cr2551/FitPath/issues/4), [#8](https://github.com/cr2551/FitPath/issues/8) |
| [#12](https://github.com/cr2551/FitPath/issues/12) | DATA-3 | Bundled starter food catalog (asset + first-launch seeding) | A: Nutrition | M | [#4](https://github.com/cr2551/FitPath/issues/4) |
| [#15](https://github.com/cr2551/FitPath/issues/15) | DATA-6 | Workout repository: exercise catalog, sessions, exercises, sets, history | B: Workouts | L | [#4](https://github.com/cr2551/FitPath/issues/4), [#9](https://github.com/cr2551/FitPath/issues/9) |
| [#16](https://github.com/cr2551/FitPath/issues/16) | DATA-7 | Starter exercise catalog (asset + first-launch seeding) | B: Workouts | S | [#4](https://github.com/cr2551/FitPath/issues/4) |
| [#17](https://github.com/cr2551/FitPath/issues/17) | DATA-8 | Dashboard layout repository, card catalog and goal-based presets | D: Dashboard, Progress & Backup | S | [#4](https://github.com/cr2551/FitPath/issues/4) |
| [#43](https://github.com/cr2551/FitPath/issues/43) | REL-1 | About screen, health disclaimer, data attribution, privacy policy and Play Data safety draft | Release | S | [#3](https://github.com/cr2551/FitPath/issues/3) |

### Wave 4

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#14](https://github.com/cr2551/FitPath/issues/14) | DATA-5 | Food search orchestration: local first, then Open Food Facts, cache on select | A: Nutrition | S | [#11](https://github.com/cr2551/FitPath/issues/11), [#13](https://github.com/cr2551/FitPath/issues/13) |
| [#18](https://github.com/cr2551/FitPath/issues/18) | ONB-1 | Onboarding: Welcome and "Let's get you set up" screens with validation | C: Onboarding & Settings | M | [#3](https://github.com/cr2551/FitPath/issues/3), [#5](https://github.com/cr2551/FitPath/issues/5), [#6](https://github.com/cr2551/FitPath/issues/6) |
| [#22](https://github.com/cr2551/FitPath/issues/22) | SET-1 | Profile & Settings screen: edit profile, units (display only), theme, entry points | C: Onboarding & Settings | M | [#10](https://github.com/cr2551/FitPath/issues/10), [#3](https://github.com/cr2551/FitPath/issues/3), [#5](https://github.com/cr2551/FitPath/issues/5), [#6](https://github.com/cr2551/FitPath/issues/6) |
| [#23](https://github.com/cr2551/FitPath/issues/23) | SET-2 | Goals and nutrition targets editing (history-preserving, offers new dashboard preset) | C: Onboarding & Settings | M | [#10](https://github.com/cr2551/FitPath/issues/10), [#17](https://github.com/cr2551/FitPath/issues/17), [#7](https://github.com/cr2551/FitPath/issues/7), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#24](https://github.com/cr2551/FitPath/issues/24) | NUT-1 | Nutrition daily overview: date selection, totals vs targets, meal groups, edit/delete entries | A: Nutrition | M | [#11](https://github.com/cr2551/FitPath/issues/11), [#10](https://github.com/cr2551/FitPath/issues/10), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#26](https://github.com/cr2551/FitPath/issues/26) | NUT-3 | Add/edit food diary entry screen | A: Nutrition | S | [#11](https://github.com/cr2551/FitPath/issues/11), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#27](https://github.com/cr2551/FitPath/issues/27) | NUT-4 | Custom food create/edit screen | A: Nutrition | S | [#11](https://github.com/cr2551/FitPath/issues/11), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#28](https://github.com/cr2551/FitPath/issues/28) | WO-1 | Workouts tab: start workout, resume in-progress session, recent history list | B: Workouts | S | [#15](https://github.com/cr2551/FitPath/issues/15), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#29](https://github.com/cr2551/FitPath/issues/29) | WO-2 | Active workout session screen: exercises, sets, reps, load, complete/discard | B: Workouts | L | [#15](https://github.com/cr2551/FitPath/issues/15), [#5](https://github.com/cr2551/FitPath/issues/5), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#30](https://github.com/cr2551/FitPath/issues/30) | WO-3 | Exercise picker and custom exercise screens | B: Workouts | S | [#15](https://github.com/cr2551/FitPath/issues/15), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#31](https://github.com/cr2551/FitPath/issues/31) | WO-4 | Completed session detail screen (review and delete) | B: Workouts | S | [#15](https://github.com/cr2551/FitPath/issues/15), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#32](https://github.com/cr2551/FitPath/issues/32) | DASH-1 | Home dashboard screen, card registry and edit mode (add/hide/remove/reorder) | D: Dashboard, Progress & Backup | M | [#17](https://github.com/cr2551/FitPath/issues/17), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#36](https://github.com/cr2551/FitPath/issues/36) | PROG-1 | Progress screen shell and time-range selector | D: Dashboard, Progress & Backup | S | [#3](https://github.com/cr2551/FitPath/issues/3), [#5](https://github.com/cr2551/FitPath/issues/5), [#6](https://github.com/cr2551/FitPath/issues/6) |
| [#40](https://github.com/cr2551/FitPath/issues/40) | BAK-1 | Versioned JSON export (backup) with share/save | D: Dashboard, Progress & Backup | M | [#4](https://github.com/cr2551/FitPath/issues/4), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#42](https://github.com/cr2551/FitPath/issues/42) | SET-3 | Reset local data with confirmation | D: Dashboard, Progress & Backup | S | [#10](https://github.com/cr2551/FitPath/issues/10), [#6](https://github.com/cr2551/FitPath/issues/6), [#3](https://github.com/cr2551/FitPath/issues/3) |

### Wave 5

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#19](https://github.com/cr2551/FitPath/issues/19) | ONB-2 | Onboarding: choose goals and goal-specific follow-up questions | C: Onboarding & Settings | S | [#18](https://github.com/cr2551/FitPath/issues/18) |
| [#25](https://github.com/cr2551/FitPath/issues/25) | NUT-2 | Food search and food details screens | A: Nutrition | M | [#14](https://github.com/cr2551/FitPath/issues/14), [#6](https://github.com/cr2551/FitPath/issues/6), [#5](https://github.com/cr2551/FitPath/issues/5), [#3](https://github.com/cr2551/FitPath/issues/3) |
| [#33](https://github.com/cr2551/FitPath/issues/33) | DASH-2 | Calories & macros dashboard card (ring + macro bars, from the reference design) | D: Dashboard, Progress & Backup | M | [#32](https://github.com/cr2551/FitPath/issues/32), [#11](https://github.com/cr2551/FitPath/issues/11), [#10](https://github.com/cr2551/FitPath/issues/10) |
| [#34](https://github.com/cr2551/FitPath/issues/34) | DASH-3 | Weight trend and nutrition summary dashboard cards | D: Dashboard, Progress & Backup | S | [#32](https://github.com/cr2551/FitPath/issues/32), [#10](https://github.com/cr2551/FitPath/issues/10), [#11](https://github.com/cr2551/FitPath/issues/11) |
| [#35](https://github.com/cr2551/FitPath/issues/35) | DASH-4 | Workout summary, recent sessions, strength progression and activity overview cards | D: Dashboard, Progress & Backup | M | [#32](https://github.com/cr2551/FitPath/issues/32), [#15](https://github.com/cr2551/FitPath/issues/15) |
| [#37](https://github.com/cr2551/FitPath/issues/37) | PROG-2 | Weight logging and weight history chart | D: Dashboard, Progress & Backup | M | [#36](https://github.com/cr2551/FitPath/issues/36), [#10](https://github.com/cr2551/FitPath/issues/10) |
| [#38](https://github.com/cr2551/FitPath/issues/38) | PROG-3 | Nutrition history charts and daily summaries | D: Dashboard, Progress & Backup | S | [#36](https://github.com/cr2551/FitPath/issues/36), [#11](https://github.com/cr2551/FitPath/issues/11) |
| [#39](https://github.com/cr2551/FitPath/issues/39) | PROG-4 | Workout history stats and exercise performance chart | D: Dashboard, Progress & Backup | M | [#36](https://github.com/cr2551/FitPath/issues/36), [#15](https://github.com/cr2551/FitPath/issues/15) |
| [#41](https://github.com/cr2551/FitPath/issues/41) | BAK-2 | JSON import/restore with validation, confirmation and transactional rollback | D: Dashboard, Progress & Backup | M | [#40](https://github.com/cr2551/FitPath/issues/40) |

### Wave 6

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#20](https://github.com/cr2551/FitPath/issues/20) | ONB-3 | Onboarding: initial estimates screen (BMR/TDEE, editable calorie and macro targets) | C: Onboarding & Settings | S | [#19](https://github.com/cr2551/FitPath/issues/19), [#7](https://github.com/cr2551/FitPath/issues/7) |

### Wave 7

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#21](https://github.com/cr2551/FitPath/issues/21) | ONB-4 | Onboarding: complete setup, persist everything, apply dashboard preset, first-launch redirect | C: Onboarding & Settings | M | [#20](https://github.com/cr2551/FitPath/issues/20), [#10](https://github.com/cr2551/FitPath/issues/10), [#17](https://github.com/cr2551/FitPath/issues/17) |

### Wave 8

| # | Key | Title | Lane | Size | Blocked by |
|---|---|---|---|---|---|
| [#45](https://github.com/cr2551/FitPath/issues/45) | REL-3 | End-to-end integration tests for the MVP acceptance criteria | Release | L | [#21](https://github.com/cr2551/FitPath/issues/21), [#24](https://github.com/cr2551/FitPath/issues/24), [#25](https://github.com/cr2551/FitPath/issues/25), [#26](https://github.com/cr2551/FitPath/issues/26), [#28](https://github.com/cr2551/FitPath/issues/28), [#29](https://github.com/cr2551/FitPath/issues/29), [#30](https://github.com/cr2551/FitPath/issues/30), [#32](https://github.com/cr2551/FitPath/issues/32), [#37](https://github.com/cr2551/FitPath/issues/37), [#41](https://github.com/cr2551/FitPath/issues/41) |
| [#46](https://github.com/cr2551/FitPath/issues/46) | REL-4 | Accessibility, responsiveness and error-state polish pass | Release | M | [#21](https://github.com/cr2551/FitPath/issues/21), [#22](https://github.com/cr2551/FitPath/issues/22), [#23](https://github.com/cr2551/FitPath/issues/23), [#24](https://github.com/cr2551/FitPath/issues/24), [#25](https://github.com/cr2551/FitPath/issues/25), [#26](https://github.com/cr2551/FitPath/issues/26), [#27](https://github.com/cr2551/FitPath/issues/27), [#28](https://github.com/cr2551/FitPath/issues/28), [#29](https://github.com/cr2551/FitPath/issues/29), [#30](https://github.com/cr2551/FitPath/issues/30), [#31](https://github.com/cr2551/FitPath/issues/31), [#33](https://github.com/cr2551/FitPath/issues/33), [#34](https://github.com/cr2551/FitPath/issues/34), [#35](https://github.com/cr2551/FitPath/issues/35), [#37](https://github.com/cr2551/FitPath/issues/37), [#38](https://github.com/cr2551/FitPath/issues/38), [#39](https://github.com/cr2551/FitPath/issues/39), [#41](https://github.com/cr2551/FitPath/issues/41), [#42](https://github.com/cr2551/FitPath/issues/42) |

## Critical path

[#1](https://github.com/cr2551/FitPath/issues/1) CORE-1 -> [#2](https://github.com/cr2551/FitPath/issues/2) CORE-2 -> [#6](https://github.com/cr2551/FitPath/issues/6) CORE-6 -> [#18](https://github.com/cr2551/FitPath/issues/18) ONB-1 -> [#19](https://github.com/cr2551/FitPath/issues/19) ONB-2 -> [#20](https://github.com/cr2551/FitPath/issues/20) ONB-3 -> [#21](https://github.com/cr2551/FitPath/issues/21) ONB-4 -> [#45](https://github.com/cr2551/FitPath/issues/45) REL-3

Keep these moving first; everything else has slack.

## Suggested assignment for 3-4 collaborators

- **Person 1 (Lane A - Nutrition):** CORE-1 first (blocks everyone), then CORE-5, CALC-2, DATA-4, DATA-2, DATA-3, DATA-5, NUT-1..4.
- **Person 2 (Lane B - Workouts):** CORE-4 (database), then CALC-3, DATA-7, DATA-6, WO-1..4, DASH-4, PROG-4.
- **Person 3 (Lane C - Onboarding & Settings):** CORE-3 (router), then CALC-1, DATA-1, ONB-1..4 (critical path - keep it moving), SET-1, SET-2, REL-1.
- **Person 4 (Lane D - Dashboard, Progress & Backup):** CORE-2 + CORE-6 (theme, widgets), then DATA-8, DASH-1..3, PROG-1..3, BAK-1, BAK-2, SET-3, REL-2.
- With 3 people, split Lane D: dashboard cards go with whoever owns the data (DASH-2/3 -> Lane A or C, DASH-4/PROG-4 -> Lane B), backup goes to Lane C.
- Everyone: REL-3 (integration tests) and REL-4 (polish) at the end, split by tab.

## Out of scope for the MVP

Cloud sync and accounts, social features, AI suggestions, image/NL food logging, barcode scanning UI, workout routines/templates, Priority 2 features (what-if calculator, streaks, PRs, 1RM, weekly reports). The v1 schema already captures the data they need.
