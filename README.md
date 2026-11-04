# FitPath

A goal-aware, customizable fitness tracker that keeps your data on your device. FitPath combines calorie and macronutrient tracking, workout logging, body-weight history and a customizable home dashboard. It needs no account.

- **Platform:** Android (Flutter), targeting Google Play
- **Data:** local-first (SQLite via Drift), with versioned JSON export/import
- **Food data:** a bundled starter catalog, Open Food Facts lookup, and custom foods

> FitPath provides estimates and tracking tools, not medical advice.

## Documents

- [Project specification (PDF)](FitPath_Project_Specification.pdf)
- [MVP implementation plan](docs/MVP_PLAN.md): waves, lanes, critical path, and the working agreement that avoids merge conflicts
- [Project board: FitPath MVP](https://github.com/users/cr2551/projects/5), with one issue per task. Start with [#1](https://github.com/cr2551/FitPath/issues/1)

## Getting started

```bash
flutter pub get
dart run build_runner build -d   # generates Drift / json_serializable code (not committed)
flutter run
```

Run the checks:

```bash
flutter analyze
flutter test
```

## Contributing

1. Pick an issue on the board whose **Blocked by** issues are all merged.
2. Branch from `main` as `<issue#>-short-name`.
3. Change only the files your issue lists under **Files / areas owned**.
4. Open a PR with `Closes #<issue#>` and get CI green.

See [docs/MVP_PLAN.md](docs/MVP_PLAN.md#working-agreement-avoiding-merge-conflicts) for details.
