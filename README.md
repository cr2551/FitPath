# FitPath

A goal-aware, customizable fitness tracker that keeps your data on your device. FitPath combines calorie and macronutrient tracking, workout logging, body-weight history and a customizable home dashboard. It needs no account.

- **Platform:** Android (Flutter), targeting Google Play
- **Data:** local-first (SQLite via Drift), with versioned JSON export/import
- **Food data:** a bundled starter catalog, Open Food Facts lookup, and custom foods

> FitPath provides estimates and tracking tools, not medical advice.

## Documents

- [Project specification (PDF)](FitPath_Project_Specification.pdf)
- [MVP implementation plan](docs/MVP_PLAN.md): waves, lanes, critical path, and the working agreement that avoids merge conflicts
- [Design guidelines](DESIGN/README.md): tokens, components, layout rules and [screen mockups](DESIGN/screens.html)
- [Project board: FitPath MVP](https://github.com/users/cr2551/projects/5), with one issue per task. Start with [#1](https://github.com/cr2551/FitPath/issues/1)

## Getting started

```bash
flutter pub get
dart run build_runner build -d   # generates Drift / json_serializable code (not committed)
flutter run
```

To try it in a browser, run `flutter run -d chrome` (or `flutter run -d web-server` and open the printed URL). In the browser the database lives in the browser's storage (IndexedDB or OPFS) through `web/sqlite3.wasm` and `web/drift_worker.js`. If you upgrade the `sqlite3` or `drift` packages, replace those two files with the matching versions from the [sqlite3.dart](https://github.com/simolus3/sqlite3.dart/releases) and [drift](https://github.com/simolus3/drift/releases) releases.

Run the checks:

```bash
flutter analyze
flutter test
```

Build a signed release bundle for Google Play (needs `android/key.properties`; see [docs/release.md](docs/release.md)):

```bash
flutter build appbundle --release
```

## Contributing

1. Pick an issue on the board whose **Blocked by** issues are all merged.
2. Branch from `main` as `<issue#>-short-name`.
3. Change only the files your issue lists under **Files / areas owned**.
4. Open a PR with `Closes #<issue#>` and get CI green.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow: board columns, branch naming, frozen files and code conventions.

## Project layout

```
lib/
  main.dart, app.dart        # entry point and root widget (frozen)
  core/                      # database, network, errors, utils, theme, router
  features/<feature>/        # onboarding, profile, dashboard, nutrition, workouts, progress, settings
  shared/                    # widgets, models (shared enums), extensions
assets/data/                 # bundled starter food and exercise catalogs
DESIGN/                      # design guidelines and mockups
```
