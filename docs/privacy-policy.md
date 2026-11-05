# FitPath privacy policy

_Last updated: 4 November 2026_

FitPath is a fitness and nutrition tracker for Android. This policy explains
what happens to the information you enter.

## The short version

- Everything you enter stays **on your phone**.
- There is **no account**, no cloud sync, no advertising and no analytics.
- The only thing that leaves your phone is the **text or barcode you search
  for** when you look up a packaged food in Open Food Facts.

## What FitPath stores, and where

FitPath stores the following in a database inside the app's private storage
on your device:

- your profile (age, height, sex if you choose to enter it, activity level,
  training experience);
- your goals, weight history and nutrition targets;
- your food diary, custom foods and foods you looked up;
- your workouts and custom exercises;
- your dashboard layout and settings (units, theme).

This data is not sent to us or to anyone else. We (the developers) cannot
see it.

## What is sent over the internet

When you search for a packaged food, FitPath sends your **search text** or
the **barcode** to [Open Food Facts](https://world.openfoodfacts.org), a free
public food database, to get matching products. The request carries a
`User-Agent` naming the app and its version, as Open Food Facts asks of all
apps. It does **not** include your profile, diary, weight or any identifier.

Open Food Facts handles these requests under its own
[privacy policy](https://world.openfoodfacts.org/privacy). Searching the
built-in food list works offline and sends nothing.

FitPath sends nothing else: no crash reports, no usage statistics, no
advertising identifiers.

## Backups

You can export a backup file (Profile > Backup & restore). The file is
created on your phone and goes only where you choose to share or save it. It
contains your personal health data, so keep it somewhere private.

## Deleting your data

- **Profile > Reset data** deletes everything you entered.
- Uninstalling the app, or clearing its storage in Android settings, also
  deletes everything.

Because nothing is stored on a server, there is nothing else to delete.

## Children

FitPath is not directed at children under 13 and does not knowingly collect
information from them. All data stays on the device in any case.

## Changes

If this policy changes, the new version is published at the same address
with a new "Last updated" date.

## Contact

Questions: open an issue at <https://github.com/cr2551/FitPath/issues>.
