# Moglog

[![Release](https://img.shields.io/github/v/release/tshivaneshk/Moglog-Releases?label=Release&color=10B981)](https://github.com/tshivaneshk/Moglog-Releases/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docs & Guide](https://img.shields.io/badge/Docs-moglog--instructions.vercel.app-1C1C1E)](https://moglog-instructions.vercel.app)

A fast, privacy-first, open-source TV show & drama tracker built with **Flutter** (`com.skech.moglog`), engineered by **SKECH by T Shivanesh Kumar**.

- **Download Signed Android APK:** [GitHub Releases](https://github.com/tshivaneshk/Moglog-Releases/releases/latest)
- **Web Companion (PWA):** [moglog-web.vercel.app](https://moglog-web.vercel.app)
- **Documentation & 7-Step TMDB Key Guide:** [moglog-instructions.vercel.app](https://moglog-instructions.vercel.app)

---

## Key Features

- **120 Hz Fluid UI & Adaptive Layouts:** iOS-inspired pure-black OLED dark mode, crisp light mode, instant dynamic poster ambient tinting, landscape 2-pane splits, and pop-up multi-window support.
- **Local-First Encrypted Database:** Full on-device SQLite database encrypted at rest with **256-bit AES SQLCipher**, plus hardware-backed secure storage for API credentials and passphrases.
- **High-Speed TMDB Integration:** Single-call `append_to_response` metadata hydration, in-flight request deduplication, 7-day persistent detail cache, pooled HTTP keep-alive image caching (`w185` / `w342` / `w500` responsive buckets), and Discover rails (Trending, Popular, Airing Today, On The Air).
- **Multi-Season Tracking & Binge Calculator:** Season breakdowns, episode steppers, next-episode air-date countdowns, estimated binge pace calculators, and completion confetti/chime celebrations.
- **Watch Circle & Taste Blend:** Connect with friends via invite codes, compare show compatibility scores, race co-watched episodes, and send quick nudges.
- **Bidirectional Cloud Sync:** Optional Google Sign-In + chunked Firestore sync with Last-Write-Wins reconciliation across Android and Web.
- **Portable Encrypted Backups & Universal CSV:** Export/import password-protected `.moglog` archives (`PBKDF2-HMAC-SHA256` 600,000 iterations + `AES-256-GCM`), plus CSV import support for Moglog, TV Time, and Trakt.
- **Privacy & Security Controls:** Biometric / Device PIN lock with configurable timeout, Android `FLAG_SECURE` app-switcher privacy shield, and a 30-day Recycle Bin.
- **Background Episode Reminders:** Native Android `WorkManager` periodic checks with rich poster notifications and deep-link routing.
- **Seamless Upgrade from Kotlin v3.0.x:** Updating from legacy Kotlin `v3.0.73` to Flutter `v3.1.0+` preserves your exact package identity and automatically migrates your SQLCipher database, Jetpack DataStore settings, and Tink secrets on first launch.

---

## Getting Started

### Prerequisites
- Flutter SDK (`>= 3.24`, Dart `^3.5.0`)
- Android SDK (API 36) & JDK 17
- A free TMDB API key ([step-by-step setup guide](https://moglog-instructions.vercel.app/obtain-api-key))

### Run Locally
```bash
git clone https://github.com/tshivaneshk/moglog-flutter.git
cd moglog-flutter
flutter pub get
flutter run
```

### Run Static Analysis & Tests
```bash
flutter analyze
flutter test
```

### Optional Firebase Setup (Cloud Sync & Watch Circle)
Moglog works fully offline without Firebase. To enable Google Sign-In and Firestore sync on your own fork:
1. Create a Firebase project and register Android package `com.skech.moglog` with your debug/release SHA-1 fingerprints.
2. Download `google-services.json` and place it in `android/app/google-services.json` (git-ignored).
3. Enable Google Sign-In in Firebase Authentication and create a Cloud Firestore database.

### Building a Signed Release APK
Add your signing properties to `android/local.properties` (git-ignored) or export them as environment variables:
```properties
RELEASE_STORE_FILE=/path/to/keystore.jks
RELEASE_STORE_PASSWORD=your_store_password
RELEASE_KEY_ALIAS=your_key_alias
RELEASE_KEY_PASSWORD=your_key_password
```
Then build:
```bash
flutter build apk --release
```

---

## Contributing

Contributions, bug reports, and feature ideas are warmly welcomed! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

## Attribution

This product uses the TMDB API but is not endorsed or certified by TMDB.
