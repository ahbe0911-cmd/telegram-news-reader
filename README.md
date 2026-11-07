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


## Direct Telegram connection (MTProto / TDLib)

The Android app uses the community-maintained `handy_tdlib_next` Flutter binding to the native TDLib JSON interface. On first launch, enter your API ID and API Hash from https://my.telegram.org, then complete Telegram's phone/code/2-step verification flow.

- API ID, API Hash and the TDLib database encryption key are stored with Android secure storage.
- Telegram authorization state and messages are stored in TDLib's encrypted app-private database.
- The app does not send login codes or account credentials to a project backend.
- This package currently targets Android only.
- The API credentials are supplied by the device owner at runtime; do not commit them to this public repository.

The app uses Android minSdk 23 because the selected secure-storage plugin requires Android 6.0 or newer.
