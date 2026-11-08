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
