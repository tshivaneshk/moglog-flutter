# Contributing to Moglog

Thank you for your interest in contributing to **Moglog**! Whether you are fixing a bug, optimizing performance, improving accessibility, or proposing a new feature, contributions are welcome.

## Development Setup

### Prerequisites
- **Flutter SDK** (`>= 3.24` / Dart `^3.5.0`)
- **Android Studio / Android SDK** (API 36, JDK 17)
- A free personal **TMDB API Key** (v3) or **v4 Read Access Token** — see the [7-Step TMDB API Key Guide](https://moglog-instructions.vercel.app/obtain-api-key).

### Running Locally
```bash
git clone https://github.com/tshivaneshk/moglog-flutter.git
cd moglog-flutter
flutter pub get
flutter run
```

> **Note on Firebase & Cloud Sync:**
> Moglog is **local-first** and works out of the box without Firebase configuration. To test Google Sign-In, Firestore Cloud Sync, or Watch Circle against your own Firebase project, place your own `google-services.json` at `android/app/google-services.json` (git-ignored). Never commit credentials, keystores, `local.properties`, or `google-services.json`.

## Code Style & Quality Checks

Before opening a pull request, please make sure all checks pass locally:

```bash
flutter analyze
flutter test
```

### Architecture Overview
- `lib/app/` — App shell, GoRouter navigation, Riverpod providers & controllers (`providers.dart`)
- `lib/core/` — Design system tokens/components, SQLCipher/backup crypto (`MOGLOG_ENC_V1`), pooled image caching, haptics, notifications, and platform channels
- `lib/data/` — SQLCipher local database (`app_database.dart`), TMDB REST API (`tmdb_api.dart`), Firestore Cloud Sync, and Watch Circle repository
- `lib/domain/` — Pure Dart models and business logic (filtering, season progress, stats/prestige tiers, Taste Blend, version checker)
- `lib/features/` — Screens organized by feature (`library`, `discover`, `detail`, `stats`, `social`, `settings`, `onboarding`)
- `android/app/src/main/kotlin/com/skech/moglog/` — Native Android platform bridge, `EpisodeReminderWorker` (WorkManager), and one-time Kotlin `v3.0.x` migrator

### Design & Product Principles
- **Privacy first:** All library data stays encrypted on-device by default; zero third-party analytics or ad SDKs.
- **No personal notes or personal tags UI:** Keep the tracking workflow clean and focused on episodes, ratings, statuses, and shelves.
- **120 Hz smoothness:** Avoid unnecessary rebuilds, heavy live blur overdraw, or duplicate network requests.

## Pull Request Process
1. Fork the repository and create a branch from `main` (e.g., `fix/poster-cache` or `feat/new-filter`).
2. Keep pull requests focused and include unit or widget tests where applicable.
3. Run `flutter analyze` and `flutter test` with zero warnings or errors.
4. Open a pull request describing the motivation, changes made, and screenshots for any UI updates.

## Reporting Issues
Please open an issue on [GitHub Issues](https://github.com/tshivaneshk/moglog-flutter/issues) with steps to reproduce, device/Android version, and Moglog app version.
