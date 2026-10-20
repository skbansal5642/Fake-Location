# Fake Location

An Android app (Flutter UI + Kotlin service) that reports a mock location to the system, so other apps see the location you choose.

## Modes

- **Schedule**: different locations for different times of day, for example A from 8 AM to 8 PM and B at night. Windows can cross midnight.
- **Fixed**: one location, all the time.
- **Near place**: rules like "when I'm within 60 m of A, or connected to Wi-Fi X, show B". Away from A, the real location is shown.

All modes support place search (OpenStreetMap, or Google Places with an API key) and **natural drift**: the reported point wanders slowly within a radius (default 10 m), with varying accuracy, like a real phone lying still.

## How it works

- A foreground service pushes the chosen location every second to Android's GPS and network test providers, and to the fused location provider used by Google apps.
- The configuration is stored natively, so the service keeps running without the UI and resumes after a reboot or app update.
- While a mock location is active, the app can't see the real GPS either. In Near place mode it therefore detects leaving A from radio surroundings: losing the rule's Wi-Fi, or no longer seeing the Wi-Fi access points and cell towers it saw on arrival.

## Setup on the phone

1. Enable Developer options and set **Select mock location app → Fake Location**.
2. Grant location permission. Near place mode needs **Allow all the time**.
3. Optionally exempt the app from battery optimization so the system doesn't stop the service.

Android only; iOS has no public API for mock locations.

## Build

```bash
flutter run --release
# Optional: use Google Places for search
flutter run --release --dart-define=PLACES_API_KEY=YOUR_KEY
```

Tests:

```bash
flutter test
cd android && ./gradlew :app:testDebugUnitTest
```

## CI and releases

- **CI** (`.github/workflows/ci.yml`) runs on every push to `main` and every pull request: analyze, Dart tests, Kotlin unit tests, and a release build. The APK is attached to the run for 14 days.
- **Release** (`.github/workflows/release.yml`) is started by hand from **Actions → Release → Run workflow** on `main`. Enter a version such as `1.2.0`; it runs the same checks, builds an APK signed with the release key, creates the tag `v1.2.0`, and publishes a GitHub Release with the APK and its SHA-256 checksum. Release notes are generated from the commits since the last release.

One-time setup for releases: create the signing key and store it as repository secrets with

```bash
tool/setup_release_signing.sh
```

It asks for a password and saves `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. Back up the keystore (default `~/.android-keys/fake-location-upload.jks`) and its password: every future release must be signed with the same key, or phones won't install it as an update.

For a locally signed build, create `android/key.properties` (git-ignored) pointing at the keystore:

```properties
storeFile=/absolute/path/to/fake-location-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

## Icon and splash

The artwork is defined in `tool/generate_brand_assets.py`, which renders the PNGs in `assets/` with headless Chrome. To regenerate:

```bash
python3 tool/generate_brand_assets.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Caveats

- Apps can tell a location is mocked (`Location.isMock`), and some apps refuse to work while mock locations are on.
- Wi-Fi and cell positioning can briefly override the mock; turning off Wi-Fi and Bluetooth scanning reduces this.
- Detecting that you've left a place while a mock is active takes a minute or two and needs Wi-Fi turned on.
