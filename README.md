# Telegram News Reader

A Persian RTL Flutter application for reading Telegram channel posts through TDLib/MTProto, with local bookmarks and offline reading.

## Project status

- Phase 1: repository bootstrap and project configuration.
- Phase 2: RSS parsing, feed repository, Isar persistence, channel management, and Riverpod dependency injection.
- Phase 3: Flutter UI, media viewers, download manager, and end-to-end polish.

## Requirements

- Flutter stable with Dart 3.13 or newer.
- Android SDK for Android builds.

## Android project scaffold

If this repository does not yet contain the generated Android Gradle wrapper files, run:

```bash
flutter create --platforms=android --project-name telegram_news_reader --org com.example --no-pub .
```

Then run:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

## Notes

Telegram messages are retrieved through the signed-in user's TDLib session. Private channels are available only when the account is already a member and the chat is present in the account's Telegram chat list.


## Persian typography

The app bundles the open-source Vazir font locally. Before building on a
development machine, run:

```bash
bash tool/prepare_fonts.sh
flutter pub get
flutter run
```

The GitHub Actions workflow runs this preparation automatically. It downloads
a pinned font revision, verifies its Git blob SHA, and includes the SIL Open
Font License in the app assets. The font is bundled in the APK and is available
offline at runtime.

## Direct Telegram connection (MTProto / TDLib)

The Android app uses the community-maintained `handy_tdlib_next` Flutter binding to the native TDLib JSON interface. On first launch, enter your API ID and API Hash from https://my.telegram.org, then complete Telegram's phone/code/2-step verification flow.

- API ID, API Hash and the TDLib database encryption key are stored with Android secure storage.
- Telegram authorization state and messages are stored in TDLib's encrypted app-private database.
- The app does not send login codes or account credentials to a project backend.
- This package currently targets Android only.
- The API credentials are supplied by the device owner at runtime; do not commit them to this public repository.

The app uses Android minSdk 23 because the selected secure-storage plugin requires Android 6.0 or newer.


## Compact news experience (1.4.0)

The UI keeps Telegram/TDLib retrieval unchanged and uses four registered Persian fonts:
Titr for headlines, Rooznameh for article bodies, Nazanin for metadata, and
Vazir for UI controls. Cards show a 3-line body preview, expandable by tapping.
Images use a 16:9 preview capped at 320 x 180 logical pixels.
In-article HTTP(S) links open via embedded WebView.
Media files download to application storage and open with internal previews
(images, video, audio, PDF, and plain text). Other binary formats show a clear
unsupported-preview message instead of forcing the user into another app.

Settings persist locally using shared_preferences: compact cards, images,
data saving, and text scale. They do not affect the Telegram session.

### Android launcher icon

The repository contains the original icon generator at
tool/generate_launcher_icons.py. After generating the Android scaffold, run:

```bash
python -m pip install pillow
python tool/generate_launcher_icons.py
```

The generator writes assets/icon/app_icon.png and all mipmap density files
and Android 8+ adaptive icon resources under android/app/src/main/res.
The manifest is already configured to use @mipmap/ic_launcher.
The GitHub APK workflow runs the generator automatically.

### Build release

```bash
flutter create --platforms=android --project-name telegram_news_reader --org com.example --no-pub .
python -m pip install pillow
python tool/generate_launcher_icons.py
bash tool/prepare_fonts.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

## Unified live feed (1.5.0)

The home feed merges posts across all enabled channels, deduplicates them by
message ID, and orders by the most recent timestamp (Telegram edit time when
available, otherwise the original publication time). Undated messages appear
after timestamped posts.

Channel history requests use a **bounded pool of three concurrent fetches**.
The native TDLib worker still uses a single receive loop and correlates each
response with its request ID. This avoids unlimited request floods while
making unrelated channel requests overlap.

The feed listens for TDLib new-message and edited-message updates and
debounces refreshes. A 35-second poll while the feed is visible provides
fallback updates for public channels that do not issue push events to this
Telegram account. As with any network app, delivery depends on connectivity
and Telegram; this does not guarantee zero-delay updates.

Each source has a deterministic accent color, and editorial headlines use the
bundled Titr font at 19 logical pixels with up to three visible lines. Tap to
expand a longer headline and the accompanying article text.

### Release APK commands

```bash
flutter create --platforms=android --project-name telegram_news_reader --org com.example --no-pub .
python3 -m pip install pillow
python3 tool/generate_launcher_icons.py
bash tool/prepare_fonts.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

ARM64 output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.


## Media and Persian dates (1.6.0)

- Each image thumbnail is tappable; HTTP(S) images open directly without forcing a download.
- Telegram images already downloading automatically queue the open action instead of
  silently ignoring taps. Downloaded Telegram images open from the TDLib local path.
- The lightbox uses InteractiveViewer (pinch to zoom 1x–5x, pan),
  a close button, and downward single-finger dismissal when not zoomed.
  TransformationController and image routes are disposed on close.
- Media tiles have distinct play and download actions. Video opens the existing
  Chewie full-screen player with a timeline. Audio opens a dedicated full-screen
  player with play/pause and seek controls. Controllers pause when the app
  backgrounds and are disposed when routes close.
- PDF attachments continue to use the built-in flutter_cached_pdfview reader.
  TDLib PDFs download to app storage before opening; HTTP PDF URLs can open in-app.
- Exact Shamsi dates are calculated from device-local DateTime with shamsi_date
  and shown below the relative time using Persian numerals in Nazanin.

### Build instructions

```bash
flutter create --platforms=android --project-name telegram_news_reader --org com.example --no-pub .
mkdir -p android/app/src/main
cp tool/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
python3 -m pip install pillow
python3 tool/generate_launcher_icons.py
bash tool/prepare_fonts.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

Find the 64-bit APK under build/app/outputs/flutter-apk/app-arm64-v8a-release.apk.


## TelePulse v1.7.0: Internal browser and read-only Office previews

Android launcher name: TelePulse (tool/android/AndroidManifest.xml).
Original launcher icon: blue/teal/violet paper plane and news sheet.
Run python3 tool/generate_launcher_icons.py after flutter create.
The generator writes legacy mipmaps, adaptive foreground/background and
Android 13+ monochrome icons. GitHub Actions runs it automatically.

All article links open in the embedded WebView by default. The browser
offers Back, Forward, Refresh and an EXPLICIT option to open outside.
WebView uses JavaScript, Android DOM storage and system browser caching.

DOCX renders paragraphs as selectable text; XLSX shows worksheet cells in
read-only scrollable tables. Parsing runs in a background isolate. The
preview is limited to 16 MiB input files and 500 rows x 32 columns per
worksheet to avoid freezing devices. Complex Office formatting, charts
and macros are not rendered or executed; original files are unchanged.

Each full-screen viewer provides Save. Images and videos go to Gallery,
documents and audio go to Downloads/TelePulse using Android MediaStore.
Only old Android versions may request legacy WRITE_EXTERNAL_STORAGE.

### Local release commands (Linux/WSL)

```bash
git clone https://github.com/ahbe0911-cmd/telegram-news-reader.git
cd telegram-news-reader
flutter create --platforms=android --project-name telegram_news_reader --org com.example --no-pub .
mkdir -p android/app/src/main
cp tool/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
python3 -m pip install pillow
python3 tool/generate_launcher_icons.py
bash tool/prepare_fonts.sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

ARM64 output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk.
Use your own release signing key for public store distribution.

## TelePulse 1.8.0: Android installation / signing / icon fix

### Why old APKs failed to update

Previous CI runs used **new runner debug signing certificates** on every build.
Android correctly refuses an in-place update when the APK has a different
signing certificate. v1.8.0 does NOT change the application ID, so the
previous app must be uninstalled once before installing the newly signed APK.
Warning: uninstalling can erase TDLib login, saved news and local settings.
Back up anything important and have your Telegram login available.

Version is centrally defined in pubspec.yaml as `1.8.0+10`.
Flutter maps 1.8.0 to Android versionName and 10 to versionCode.

### Icon: repeatable Android launcher generation

Run after scaffolding the Android project:

```bash
python3 -m pip install pillow
python3 tool/generate_launcher_icons.py
flutter pub get
dart run flutter_launcher_icons
```

The script creates these **1024 x 1024 PNG** sources in assets/icon:

- `app_icon.png` (opaque legacy icon)
- `app_icon_foreground.png` (transparent adaptive foreground)
- `app_icon_background.png` (adaptive full-size background)
- `app_icon_monochrome.png` (white-on-transparent Android 13+ theme icon)

pubspec.yaml configures flutter_launcher_icons ^0.14.4 to generate all
mipmap density resources and adaptive XML. If using your own icon artwork,
replace the source PNGs after the Python step and run the Dart icon generator.
An intentional re-install is necessary to confirm the launcher refresh.

### Signing (production and future update compatibility)

**Never commit .jks, .keystore, or android/key.properties to the repository.**
The build patches Flutter's generated android/app/build.gradle.kts using:

```bash
python3 tool/configure_android_release.py
```

Create a permanent keystore yourself and save a backup somewhere safe:

```bash
keytool -genkeypair -v -storetype PKCS12 -keystore "$HOME/telepulse-release.jks" \
  -alias telepulse -keyalg RSA -keysize 3072 -validity 10000
```

Then create `android/key.properties` on your computer (NOT in git):

```properties
storeFile=/absolute/path/to/telepulse-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=telepulse
keyPassword=YOUR_KEY_PASSWORD
```

For GitHub CI builds, set these four GitHub Actions repository secrets:

- TELEPULSE_KEYSTORE_BASE64 = base64 -w0 "$HOME/telepulse-release.jks"
- TELEPULSE_KEYSTORE_PASSWORD
- TELEPULSE_KEY_ALIAS = telepulse
- TELEPULSE_KEY_PASSWORD

To set secrets: GitHub repository Settings > Secrets and variables > Actions >
New repository secret. Then every CI build can be signed using the same key.
WITHOUT those secrets, CI creates a TEST-only key for that build (different
on the next run). Such APKs require uninstalling the previous APK and are
NOT suitable for release updates or the Play Store.

### Exact universal release build commands (Linux / WSL)

```bash
git clone https://github.com/ahbe0911-cmd/telegram-news-reader.git
cd telegram-news-reader
flutter create --platforms=android --project-name telegram_news_reader --org com.example --no-pub .
mkdir -p android/app/src/main
cp tool/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts
python3 tool/configure_android_release.py
python3 -m pip install pillow
python3 tool/generate_launcher_icons.py
bash tool/prepare_fonts.sh
flutter pub get
dart run flutter_launcher_icons
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
# Requires a private android/key.properties as documented above
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

The **universal APK** is located at:
`build/app/outputs/flutter-apk/app-release.apk`.

Verify the signature and both v1/v2 schemes:

```bash
"$ANDROID_HOME/build-tools/$(ls "$ANDROID_HOME/build-tools" | sort -V | tail -1)/apksigner" \
  verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

To identify a device install failure, use:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

If adb returns INSTALL_FAILED_UPDATE_INCOMPATIBLE, the installed app has
a different signing key and must be removed before installing this package.
Android may reject installation for other reasons including insufficient
storage, insufficient SDK version, device policy or a corrupt download.

