# Google Play store listing

Draft copy and an asset checklist. Capture screenshots near the end, from a
release build with realistic sample data (never real personal data).

## App details

| Field | Value |
|---|---|
| App name (30 chars max) | FitPath: Food & Workout Log |
| Category | Health & Fitness |
| Contact email | (the developer account email) |
| Privacy policy | https://cr2551.github.io/FitPath/privacy-policy |
| Contains ads | No |
| In-app purchases | No |

## Short description (80 chars max)

> Track food, macros, workouts and weight. No account; your data stays on you.

(75 characters.)

## Full description (4,000 chars max)

> FitPath is a simple fitness tracker that keeps everything on your phone.
> No account, no cloud, no ads.
>
> **Food and macros**
> - Log meals from a built-in list of common foods, or search millions of
>   packaged products in Open Food Facts.
> - See calories against your goal, split into protein, carbs and fat.
> - Create your own foods with the values from the label.
>
> **Workouts**
> - Log exercises, sets, reps and weight as you train.
> - Pick from about 80 common exercises or add your own.
> - Compare your best sets with last time.
>
> **Weight and progress**
> - Log your weight and follow the trend toward your target.
> - Charts for weight, calories and workouts over 7 days to all time.
>
> **Your dashboard**
> - Choose the cards you want on Home and put them in your order.
> - Start with a layout that suits your goal: lose weight, build muscle,
>   maintain, get stronger or general fitness.
>
> **Private by design**
> - Everything is stored only on your device.
> - Export a backup file whenever you like, and restore it on a new phone.
>
> FitPath gives estimates and tracking tools, not medical advice. Talk to a
> doctor or dietitian before major changes to your diet or training.
>
> Food data from Open Food Facts (openfoodfacts.org), available under the
> Open Database License.

## Graphics checklist

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512 PNG, 32-bit, no transparency. Export from `assets/icon/icon.png`. | To export |
| Feature graphic | 1024 × 500 PNG/JPG. Açaí background, white chart glyph on the left, "FitPath" in Barlow Condensed Bold white, tagline "Food, workouts, weight. On your phone." No device frames or screenshots in it. | To make |
| Phone screenshots | 2–8, 9:16, at least 1080 px on the short side | To capture |

### Screenshots to capture (in this order)

1. **Home**: calories ring on track, quick actions, weight card.
2. **Nutrition day**: a full day with all four meals.
3. **Food search**: local and Open Food Facts results.
4. **Active workout**: an exercise with completed sets.
5. **Progress, Weight**: 90-day chart trending toward the target.
6. **Dashboard edit mode**: cards being reordered.
7. **Profile**: estimates card and settings.

Captions (optional overlay, Barlow Condensed, ink on white):
"Calories and macros at a glance", "Log a meal in seconds",
"Every set, every rep", "See the trend", "Your Home, your cards",
"No account. Your data stays on your phone."

## Before submitting

- [ ] Signed bundle built (`docs/release.md`) and tested on a phone.
- [ ] Privacy policy published (GitHub Pages enabled).
- [ ] Data safety form filled from `docs/play-data-safety.md`.
- [ ] Content rating questionnaire done.
- [ ] Target API level meets the current Play requirement.
