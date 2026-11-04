# FitPath design and layout guidelines

> **Status:** v3, accepted as the working direction.
> - [`screens.html`](screens.html): all five main screens in the v3 style.
> - [`home.html`](home.html): the Home screen in detail, with every calorie-ring state and the selected-day options.
> - Previous iterations are in [`archive/`](archive/) (`screens-v1.html`, `home-v2.html`).
>
> Implemented by [#2 Theme and design tokens](https://github.com/cr2551/FitPath/issues/2) and [#6 Shared UI components](https://github.com/cr2551/FitPath/issues/6).

## Changelog

**v5 (no pastels; implemented in `lib/core/theme/`)**
- Project rule: **no pastel colors**. The light açaí tint `accentSoft` is removed.
  - The active tab is now a **solid açaí indicator with a white icon**.
  - The selected-day marker is white.
  - The flame tile uses `subtle`.
- The faintly green-tinted greys (background, subtle, line, muted text) became **neutral greys**, so no surface reads as mint.
- Dark-theme values were finalized and contrast-checked by tests.

**v4 (food palette)**
- **Carbs is green** (`#7DB547`, pea/leaf green: vegetables, grains), not blue. Blue doesn't read as food.
- **The accent is açaí purple** (`#5B2A6E`, berries, beets, açaí bowls) instead of lime, which didn't read as food either. It is used for the main action, the active tab, the selected-day marker and the latest chart point.
- The macro trio is now **red protein, green carbs, yellow fat**: meat or fish, greens and grains, butter and oils.

**v3 (workshop 2 feedback)**
- **Calories card:** the layout now follows the reference image. Header with icon + "Calorie goal" + kcal remaining, then the ring on the left and the macro list on the right, then a footer strip with daily status.
- **No forest-green hero block.** Every card is light. The dark color is now a near-black `ink`, used for text, the selected day and primary buttons.
- **Selected day:** not orange. It is now an `ink` tile with white text and a lime marker. Alternatives are shown in `home.html`.
- **Ring gaps:** 10 px (about 8°) between every segment, including the start and end of the empty track (was 3 px).
- **Centered screen header** like the reference: profile button, title, layout-edit button.

**v2 (workshop 1 feedback)**
- Moved away from the report/announcement feel of v1: no terracotta accent, no serif numbers, no grey-on-off-white.
- Fat is yellow; protein red; carbs blue.
- The calorie ring is split into macro segments by calories eaten.

## 1. Direction in one paragraph

Light, fresh and athletic. A neutral light-grey background carries **white cards**. Text, the selected state and primary buttons use a **near-black ink**. **Açaí purple** is the accent, used for the main action ("Log food"), the active tab and the latest chart point. The **macro colors are the stars**, taken from real food: red protein, green carbs, yellow fat, shown in the ring and the macro bars. Headlines and numbers use a **condensed athletic sans** that reads like a scoreboard. The structure stays disciplined: corners at most 8 px, flat color, no gradients and no shadows.

## 2. Design tokens

All values live in `lib/core/theme/` and nowhere else.

### Color

| Token | Light | Use |
|---|---|---|
| `background` | `#F5F5F4` | App background (neutral light grey) |
| `surface` | `#FFFFFF` | Cards, sheets, bottom navigation |
| `subtle` | `#E9EAE7` | Unselected date tiles, icon buttons, card footer strip, icon tiles |
| `ink` | `#121815` | Primary text, icons, **selected day**, primary buttons, week markers |
| `inkMuted` | `#5E625F` | Secondary text, captions (6.2:1 on white) |
| `line` | `#DEDFDB` | 1 px borders, dividers, empty ring track, empty bar tracks |
| `accent` | `#5B2A6E` | Açaí purple: "Log food" button fill (white text, 10.5:1), active-tab icon, "live" marker, latest chart point. Safe as text on white. |
| `protein` | `#EF4C4C` | Protein (red) |
| `carbs` | `#7DB547` | Carbs (pea/leaf green) |
| `fat` | `#F7B500` | Fat (yellow) |
| `unknown` | `#A2A7A3` | Calories whose macro split is unknown |
| `success` | `#18804A` | Positive change (4.9:1 on white) |
| `warning` | `#9A5A00` | Over target, missing data (5.5:1 on white) |
| `error` | `#C6282B` | Destructive actions, validation errors |

**Macro colors on white.**
- Protein (3.6:1) passes the 3:1 contrast WCAG asks for graphics. Green carbs (2.4:1) and yellow fat (1.8:1) do not. So **color is never the only cue**: the ring always sits next to its legend, every bar carries its name and grams in text, and each macro has its own icon.
- **Color-blind safety:** red protein and green carbs can look alike to people with red-green color blindness. The fixed segment order (protein, then carbs, then fat), the icons and the text labels keep them distinguishable, and the green is deliberately much lighter than the red.

The dark theme uses `#0F1110` background, `#181B19` surface and `#EDEFEC` ink, with the same macro colors. The accent is lightened to `#A866C5` with dark text on it (4.85:1). It is wired up but only lightly polished for the MVP.

### Typography

Both fonts are OFL-licensed and **bundled** with the app, never downloaded at runtime.

| Style | Font | Size / weight | Use |
|---|---|---|---|
| `hero` | Barlow Condensed | 40 / 700 | The number inside the calorie ring |
| `display` | Barlow Condensed | 32 / 700 | Big stats (weight) |
| `headline` | Barlow Condensed | 26 / 700 | Centered screen title |
| `cardTitle` | Barlow Condensed | 22 / 600, sentence case | Card titles ("Calorie goal: 2,100 kcal") |
| `body` | Barlow | 15 / 400 | Default text |
| `bodyStrong` | Barlow | 15 / 600 | Row titles, macro names |
| `label` | Barlow | 13 / 500 | Buttons, captions |
| `overline` | Barlow Condensed | 12 / 600, uppercase, +0.08em | Weekdays, stat labels |
| `numeric` | tabular figures | inherits | Every number that changes |

### Spacing, shape and depth

- **Spacing:** 4-pt scale (`4, 8, 12, 16, 24, 32`). The screen gutter is 16, and gaps between cards are 12.
- **Radius:** `none = 0` (dividers, bars, ring segment ends), `sm = 4` (buttons, inputs, chips, nav indicator), `md = 8` (cards, sheets, dialogs, date tiles, icon buttons). **8 px is the maximum**, so there are no pill shapes. The date tiles are the reference's pills translated to 8 px rectangles.
- **Depth:** elevation 0. White cards on the grey background with a 1 px `line` border. There are **no shadows and no gradients**.
- **Bars and arcs:** square ends, never rounded caps.
- **Icons:** outlined, 22 px, 1.5 px stroke. Small icon tiles (36 px square, 8 px radius, `subtle` fill) are allowed in card headers. Icons never sit inside circles.

## 3. Components

All of these are built once in `lib/shared/widgets/` (#6). Feature screens compose them and do not restyle them.

| Component | Notes |
|---|---|
| `ScreenHeader` | Three slots: leading icon button (profile), **centered title**, trailing icon button (e.g. edit layout). Icon buttons are 40 px squares, 8 px radius, `subtle` fill. |
| `SectionCard` | `surface`, 1 px `line` border, 8 px radius, 16 px padding. Optional header (icon tile + title + subtitle), divider, body and footer strip. |
| `CardFooterStrip` | `subtle` background, 4 px radius, items separated by a 1 px vertical line, each with a small icon + text |
| `MacroCalorieRing` | See section 4 |
| `MacroLegendRow` | Icon + macro name, share of calories on the right, 6 px square-ended bar, then `consumed g / target g`. If the target is unset, it shows "Set target" instead of the bar. |
| `DateStrip` | Seven tiles (8 px radius) showing the weekday overline and date number. Unselected: `subtle` fill, `ink` date. Past days are muted. Selected: **`ink` fill, white text, white marker**. A 4 px square marker under the date means "has entries". |
| Buttons | **Accent** (açaí fill, white text) for the single most important action (Log food). **Primary** (ink fill, white text). **Outlined** (ink border). **Text** (ink, semibold). All 4 px radius, 48 px tall. |
| `ListRow` | Full-bleed row with a 1 px divider; title + subtitle on the left, value + chevron on the right |
| `SegmentedControl` | Joined 4 px segments; selected = ink fill, white text |
| `EstimateBadge` | Square, outlined overline label "ESTIMATE"; tap opens an explanation sheet |
| `EmptyState` | One line of muted text + one action |
| Bottom navigation | White bar, five labeled items; the active item has a 48x28 solid `accent` rectangle (4 px radius) behind a white icon, with an `ink` label |

## 4. Home calorie ring (`MacroCalorieRing`)

### What it shows
1. **Arc length = progress toward the calorie goal.** The colored part spans `eaten / goal` of the circle, from 12 o'clock clockwise. The rest is the empty `line`-colored track, which means "left".
2. **Segments = where the eaten calories came from**, in the fixed order **protein (red), carbs (green), fat (yellow)**. Each segment is proportional to that macro's calories:
   - `proteinKcal = g x 4`, `carbsKcal = g x 4`, `fatKcal = g x 9` (Atwater factors).
   - Share = `macroKcal / (proteinKcal + carbsKcal + fatKcal + unknownKcal)`.
3. **Gaps:** a **10 px gap (about 8° at the Home size)** sits at every boundary: between segments and at both ends of the empty track. Each segment gives up half a gap at each end, so proportions stay exact.
4. **Center:** an "Eaten" overline, the eaten kcal (hero number) and "kcal".
5. **Square ends**, 18 px stroke.

### Layout (as in the reference)
- Inside the calories `SectionCard`:
  1. **Header:** a `subtle` flame icon tile, then "Calorie goal: 2,100 kcal" with the subtitle "**460** kcal remaining today" (or "**120** kcal over today" in `warning`).
  2. **Body:** the ring (**about 170 px** in diameter on a 360 dp phone, taking about half the card width) on the left. On the right, three `MacroLegendRow`s in the same order and colors as the segments.
  3. **Footer strip:** "3 meals logged today" | "2 workouts this week".
- The `DateStrip` sits **above** the card, under the screen header, as in the reference. The selected day drives the card.
- **Accessibility:** one semantics label, e.g. "1,640 of 2,100 calories eaten, 460 left. Protein 27 percent, carbs 44 percent, fat 29 percent."

### Edge cases (all shown in `home.html`)
| State | Behaviour |
|---|---|
| On track | As above. |
| Over target | Full circle split by macro (gaps kept). Subtitle "`N` kcal over today" in `warning`. The ring never draws more than 360°. |
| Nothing logged | Only the empty track (no gaps). Center "0", subtitle "Log your first meal". |
| Unknown macros | Calories from food entries with missing macro data form a grey `unknown` segment after fat, so the arc still matches total calories. The legend gets a fourth row "Unknown". |
| No calorie goal | Full circle split by macro, with no progress meaning. The header reads "Set a calorie goal". |
| Rounding differences | The arc length always uses **label calories**; segments split that arc proportionally. |

### Implementation note
`MacroCalorieRing` is a pure layout widget built on a `CustomPainter`. It takes `eatenKcal`, `goalKcal?`, a list of `(color, kcal)` segments and `gap`, and does no nutrition math itself. The container computes the segments with #8's nutrition math.

## 5. Keeping layout independent from logic

### Three layers in every feature's `presentation/` folder

```
features/dashboard/presentation/cards/
  calories_macros_card.dart        # 1. Container: reads providers, maps to view data, handles taps
  calories_macros_card_view.dart   # 2. View: pure layout; plain values + callbacks in, widgets out
  calories_macros_view_data.dart   #    Small immutable class the view renders
```

1. **Container.** A `ConsumerWidget`. It is the only layer that touches Riverpod, `go_router` and domain objects. It converts domain data into view data (already formatted in the user's units) and passes callbacks. It contains no styling.
2. **View.** A `StatelessWidget` that takes **only plain view data and callbacks**. It composes shared components and reads styling only from the theme.
3. **Shared components** (`lib/shared/widgets/`). These are generic and know nothing about features.

### Rules
- Views never import from `data/`, `application/` or `domain/` folders, and never import Riverpod.
- Feature code never uses hex colors, `BorderRadius.circular(n)`, `TextStyle(fontSize: n)` or font names. It always goes through `Theme.of(context)`, `context.fitColors` or `context.textStyles`.
- Shared components take their own parameters and don't depend on each other's internals.
- Dashboard cards follow the same split: the card registry maps a card type to a container, which wraps a view.

### What this buys us
- **Restyle:** change tokens in `core/theme/`. The v2 to v3 change (green hero to light card, new selection color) would only have touched the theme, the shared widgets and one card view.
- **Redesign a screen or card:** replace one `*_view.dart` file.
- **Testing:** views can be widget- and golden-tested with hand-written view data.

We are not adding a separate design-system package, code-generated tokens or custom lint rules for the MVP. The rules are enforced in code review.

## 6. Screen notes

### Home (v3, see `home.html`)
- **Header:** profile button, centered "Today", layout-edit button. A goal line below it: "Lose weight · 72 kg by 1 Mar".
- **Date strip** for the current week; the selected day is ink with a white marker.
- **Calories card** (reference layout, section 4).
- **Quick actions:** **Log food** (açaí) and **Start workout** (ink).
- **Weight** and **This week** cards below. Order and visibility are user-configurable (FR-12).

### Nutrition (see `screens.html`)
- **Header:** centered title, with a "+" button for creating a custom food.
- **Day controls:** the same `DateStrip` as Home, then the search field.
- **Summary card:** a compact `MacroCalorieRing` (84 px, 6 px gaps, % of goal in the center) beside three mini macro bars.
- **Meals:** one white card per meal, with the meal total and a "+" that opens search with the meal preselected. Rows show the food name, quantity, source and kcal. An empty meal shows "Nothing logged yet" with an "Add food" action.

### Workouts
- **Open session first:** a session left in progress comes first as a card with an ink left edge, an açaí "live" marker and set progress, with Resume (primary) and Discard (error text) buttons.
- **Start button:** "Start new workout" is outlined while a session is open. Otherwise it is the accent (açaí) button.
- **This week:** the week strip plus Sessions / Sets / Volume stat tiles.
- **Recent sessions:** a list card. A history button sits in the header.

### Progress
- **Controls:** an ink `SegmentedControl` (Weight / Nutrition / Workouts), then range buttons (7D / 30D / 90D / 1Y / All), shared by all three tabs.
- **Weight:** current value + change, then the chart, then Start / Lowest / Average stats, then an entries list.
- **Chart convention:** measured values are solid ink, targets and estimates are dashed, and the latest point is an açaí square.

### Profile & Settings
- **Cards:** "Your details" (Edit) and "Estimates" (with the `EstimateBadge`).
- **Settings:** grouped white cards with plain rows: Goals & targets, Preferences (units toggle, theme, dashboard cards), Your data (export with a "never exported" warning, import, reset).
- **Header:** an info button opens About & disclaimer.

## 7. Working on the design in parallel

The four lanes (see `docs/MVP_PLAN.md`) can design and build their screens independently if they follow these rules:

1. **Tokens and shared components come first.** Feature screens are built on #2 (theme) and #6 (shared components). Until those are merged, mock screens in HTML, not Flutter.
2. **One mockup file per screen or flow**, in `DESIGN/screens/<lane>-<screen>.html` (e.g. `nutrition-food-search.html`, `workouts-active-session.html`). Never edit someone else's mockup file, and don't edit `screens.html` in parallel; it only changes when the team agrees on a new version.
3. **Copy the `:root` token block** from `screens.html` into each new mockup and use only those variables. If a mockup needs a value that isn't a token, that is a design change (see rule 4).
4. **New shared components or token changes go through a small PR to this README**, reviewed by at least one other lane, before anyone builds them. Never invent a one-off card, button or color inside a feature.
5. **Reuse the existing patterns** before adding new ones: `ScreenHeader`, `DateStrip`, `SectionCard` with list rows, `StatTile` rows, `SegmentedControl`, the chart convention (measured solid, target dashed, latest point açaí square).
6. **Implementation follows the container/view split** (section 5). Redesigning later means replacing `*_view.dart` files only.

### Screens still to mock (by lane)
| Lane | Screens |
|---|---|
| A · Nutrition | Food search (local + online results, offline banner), food details, add/edit entry, custom food |
| B · Workouts | Active session (sets table), exercise picker, custom exercise, session detail |
| C · Onboarding & Settings | Welcome, setup, goals, goal details, initial estimates, profile edit, goals, targets |
| D · Dashboard, Progress & Backup | Dashboard edit mode, Progress Nutrition/Workouts tabs, backup & restore, reset, about |

## 8. Open questions for the workshop

1. **Selected-day color:** ink (current) or açaí fill?
1. **Accent alternatives** if açaí doesn't land: beet (`#8E2A4F`), olive (`#55642A`) or ink only (no color accent).
2. **Ring size:** about 170 px beside the legend (reference layout), or a larger ring with the legend underneath?
3. **Footer strip contents:** meals logged + workouts this week, or something else (a logging streak is a Priority 2 feature)?
4. **Quick actions:** keep both buttons under the card, or use a single floating "Log" button?
5. **Dark mode:** polish it for the MVP, or ship light only?
