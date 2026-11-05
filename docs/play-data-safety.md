# Google Play: Data safety and content rating (draft)

Draft answers for the Play Console forms, based on the MVP behaviour. Re-check
them against the final build before submitting (#44), and again whenever a
feature sends data off the device.

## Data safety

### Data collection and security

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | All personal data is stored only on the device. Play counts data as "collected" only when it is transmitted off the device. |
| Is all of the user data collected by your app encrypted in transit? | Yes | Open Food Facts requests use HTTPS. |
| Do you provide a way for users to request that their data is deleted? | Yes | In-app **Reset data**; uninstalling also deletes everything. No server-side data exists. |

### Open Food Facts searches

The search text or barcode a user types is sent to Open Food Facts to find
products. It is:

- not linked to the user (no account, no identifier, no profile data),
- processed ephemerally to answer the request,
- not one of the personal data types Play lists.

Play treats data sent off the device only to fulfil a user's request in real
time, and not stored or linked to the user, as exempt from "collection".
Re-read the
[current Play definitions](https://support.google.com/googleplay/android-developer/answer/10787469)
before submitting. If they disagree, declare **App activity > Other actions
(search text)**: not shared, processed ephemerally, required for food search.

### Data types (if the form asks per type)

| Category | Collected? | Notes |
|---|---|---|
| Location | No | |
| Personal info (name, email, ids) | No | No account. |
| Financial info | No | |
| Health and fitness | No (stored on device only) | Weight, diet and workouts never leave the device. |
| Messages, photos, audio, files, calendar, contacts | No | Backup files are created only when the user exports and shares them. |
| App activity | No (see the search note above) | |
| Web browsing | No | |
| App info and performance (crash logs, diagnostics) | No | No crash reporting SDK. |
| Device or other ids | No | No advertising id. |

## Privacy policy URL

`https://cr2551.github.io/FitPath/privacy-policy`, published from
`docs/privacy-policy.md` with GitHub Pages (Settings > Pages > Deploy from a
branch: `main`, folder `/docs`). Enable Pages before submitting.

## Permissions

| Permission | Why |
|---|---|
| `INTERNET` | Open Food Facts search. |
| `ACCESS_NETWORK_STATE` | Shows an offline state instead of failing searches (`connectivity_plus`). |

No location, camera, contacts or storage permission. Saving a backup uses the
system file picker, which needs none.

## Content rating (IARC questionnaire)

| Topic | Answer |
|---|---|
| Category | Health & Fitness (utility) |
| Violence, sexuality, language, controlled substances | None |
| Gambling | None |
| Users interact or share content with each other | No |
| Shares the user's location | No |
| Digital purchases | No |

Expected rating: **Everyone / PEGI 3**.

## Health apps declaration

FitPath is a general fitness and nutrition tracker. It does not diagnose,
treat or prevent any condition and is not a medical device; the in-app health
disclaimer (About screen) says so. Declare it under **Health & Fitness**, not
**Medical**.

## Ads

Contains ads: **No**.
