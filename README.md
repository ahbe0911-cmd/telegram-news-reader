# Telegram News Reader

A Persian RTL Flutter application for reading public Telegram channel posts through RSSHub, with local bookmarks and offline reading.

## Project status

- Phase 1: repository bootstrap and project configuration.
- Phase 2: RSS parsing, feed repository, Isar persistence, channel management, and Riverpod dependency injection.
- Phase 3: Flutter UI, media viewers, download manager, and end-to-end polish.

## Requirements

- Flutter stable with Dart 3.13 or newer.
- Android SDK for Android builds.

## RSSHub

The default RSSHub base URL is `https://rsshub.app`. For reliability and rate-limit control, a self-hosted RSSHub instance is recommended.

You can override it at build time:

```bash
flutter run --dart-define=RSSHUB_BASE_URL=https://your-rsshub.example
```

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

RSS feeds are finite snapshots, not a guaranteed historical archive. The feed repository paginates the entries returned by RSSHub locally. Availability and media completeness depend on Telegram's public web preview and the configured RSSHub instance.
