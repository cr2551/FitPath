# Building a release

FitPath ships to Google Play as a signed Android App Bundle (`.aab`).

## 1. Create the upload keystore (once)

```bash
keytool -genkey -v -keystore ~/fitpath-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep the `.jks` file and its passwords somewhere safe (a password manager).
Losing them means you can't publish updates without asking Google to reset
the upload key. Never commit them: `*.jks`, `*.keystore` and
`android/key.properties` are gitignored.

Enrol the app in **Play App Signing** when you create it in the Play
Console. Google then holds the app signing key, and this keystore is only the
upload key.

## 2. Point the build at it

Create `android/key.properties`:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=C:/Users/<you>/fitpath-upload.jks
```

`android/app/build.gradle.kts` signs release builds with this file. Without
it, release builds use the debug key: fine for `flutter run --release`, but
Play rejects them.

## 3. Set the version

`pubspec.yaml`: `version: 0.1.0+1` is `versionName+versionCode`. Increase
the number after `+` for every upload; Play rejects a code it has seen.

## 4. Build

```bash
dart run build_runner build -d
flutter build appbundle --release
```

The bundle is at `build/app/outputs/bundle/release/app-release.aab`.

Release builds run R8 (code shrinking and obfuscation) and resource
shrinking. Before uploading, install a release build on a phone
(`flutter run --release`) and check that the app starts, the database opens
(add a food, log a workout, restart the app) and food search works online.

## 5. Platform levels

| Setting | Value | Source |
|---|---|---|
| `minSdk` | 24 (Android 7.0) | Flutter default |
| `targetSdk` / `compileSdk` | 36 (Android 16) | Flutter default; meets Play's target API requirement |

Play raises the target API requirement every year (usually by 31 August).
Check the [current requirement](https://developer.android.com/google/play/requirements/target-sdk)
before each release; upgrading Flutter usually raises `targetSdk` with it.

## Launcher icon

Sources are in `assets/icon/` (`icon.png`, and `icon_foreground.png` for the
adaptive and monochrome icons on the açaí background). After changing them:

```bash
dart run flutter_launcher_icons
```
