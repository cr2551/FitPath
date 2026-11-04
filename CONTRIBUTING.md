# Contributing to FitPath

The full plan, lanes and dependency waves are in [docs/MVP_PLAN.md](docs/MVP_PLAN.md). The design rules are in [DESIGN/README.md](DESIGN/README.md).

## Picking up work

1. On the [project board](https://github.com/users/cr2551/projects/5), take an issue in **Ready**. All of its **Blocked by** issues must already be merged.
2. Assign yourself and move the card to **In progress**.
3. When you open your PR, move the card to **In review**. It moves to **Done** when the PR merges.
4. When your PR unblocks other issues, move those from **Backlog** to **Ready**.

## Branches and pull requests

- Branch from an up-to-date `main`: `git switch main && git pull && git switch -c <issue#>-short-name`, e.g. `13-open-food-facts-client`.
- **One issue per branch, one branch per PR.** Write `Closes #<issue#>` in the PR description.
- Keep PRs small. CI must be green, and one other collaborator reviews.
- Use **squash merge**, then delete the branch.
- Before opening the PR, rebase on or merge the latest `main`.

## Avoiding merge conflicts

- **Only change the files your issue lists under "Files / areas owned".** If you need a change in a file another issue owns, comment on that issue or open a tiny separate PR.
- **Frozen files:**
  - `pubspec.yaml` (the fonts section belongs to #2)
  - `lib/app.dart`, `lib/main.dart`
  - `lib/core/router/app_router.dart` and `routes.dart`, after #3
  - `lib/core/database/app_database.dart`, after #4

  Each feature plugs into these through its own files.
- **Need a new package?** Open a dedicated PR that only touches `pubspec.yaml` / `pubspec.lock`, and merge it quickly.
- **Generated code is not committed.** After pulling, run:

  ```bash
  dart run build_runner build -d
  ```

## Before you push

```bash
dart format lib test
flutter analyze
flutter test
```

CI runs the same steps (plus code generation) on every PR.

## Code conventions

- Feature folders separate `presentation/`, `application/` (Riverpod providers), `domain/` (pure Dart) and `data/` (repositories, DAOs, API clients). Only create the folders you need.
- Screens follow the **container / view** split from `DESIGN/README.md` section 5. Views take plain data and callbacks; they never import Riverpod or the data layer.
- Never hard-code colors, radii, font sizes or font names in feature code. Use the theme.
- Store canonical metric units (kg, cm, g, ml); convert only for display.
- Database writes that touch several rows use a transaction.
