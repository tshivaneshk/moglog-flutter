# Moglog Kotlin-to-Flutter Migration Plan

- **Source Project (Read-Only):** `C:\Users\tshiv\AndroidStudioProjects\Moglog` (`com.skech.moglog`, v3.0.73)
- **Target Project (Flutter):** `D:\Antigravity\Moglog\moglog-flutter` (`com.skech.moglog.flutter`, v3.0.73+13)
- **Target Platforms:** Android first (`minSdk = 29`, `compileSdk = 35/36`, `targetSdk = 35`), written platform-agnostically for straightforward iOS support.

---

## 1. Flutter Architecture (Feature-First Clean Architecture)

```text
lib/
├── main.dart                                # App bootstrap, Firebase safe-init, WorkManager, Riverpod root
├── app/
│   ├── app.dart                             # MaterialApp.router, ThemeMode, Splash overlay, AppLockOverlay, Toast
│   ├── router.dart                          # go_router StatefulShellRoute (4 tabs) + iOS slide/parallax subroutes
│   └── providers.dart                       # Top-level DI providers (DB, SecureStore, Settings, Repos, Controllers)
├── core/
│   ├── design_system/
│   │   ├── tokens.dart                      # ThemeExtension<MoglogColors> (Dark default + Light semantic tokens)
│   │   ├── typography.dart                  # Inter variable font on exact iOS type scale
│   │   ├── shapes.dart                      # SmoothRoundedCornerShape (squircle Path clipper + standard radii)
│   │   ├── icons.dart                       # All 36+ rounded-outline Lucide icons (MoglogIcons)
│   │   ├── motion_haptics.dart              # Press-scale spring button, reduce-motion aware, custom vibration pulses
│   │   ├── components.dart                  # IosLargeTitleHeader, IosFrostedBar, IosGroupedSection/Row, IosSwitchRow,
│   │   │                                    # IosSegmentedControl, IosSearchBar, IosButtons, IosBottomSheet,
│   │   │                                    # IosActionSheet, IosEmptyState, IosToastBanner, ShimmerBox
│   │   └── theme.dart                       # MoglogTheme builder
│   ├── security/
│   │   ├── backup_crypto_envelope.dart      # Byte-compatible MOGLOG_ENC_V1 (PBKDF2-HMAC-SHA256 + AES-256-GCM + AAD)
│   │   ├── secure_store.dart                # flutter_secure_storage wrapper (TMDB key, DB key, backup passphrase)
│   │   └── app_lock_overlay.dart            # Biometric / Device PIN lock overlay + lifecycle timeout + privacy shield
│   ├── platform/
│   │   └── platform_bridge.dart             # MethodChannel com.skech.moglog.flutter/platform (FLAG_SECURE, installed apps, nflx://, MediaStore)
│   ├── notifications/
│   │   └── notification_service.dart        # Episode Air-Date Reminders & Watch Circle Social channels + tap routing
│   ├── background/
│   │   └── background_workers.dart          # WorkManager daily Recycle Bin purge + 12h Episode Reminder worker
│   └── celebration/
│       └── show_completion_celebration.dart # 85-particle confetti canvas + pure-Dart PCM WAV chime + victory haptic
├── data/
│   ├── local/
│   │   ├── app_database.dart                # Drift encrypted SQLite (SQLCipher 256-bit AES): dramas, shortcuts, drama_details_cache
│   │   ├── settings_store.dart              # SharedPreferences-backed AppSettings (all 21 keys + \u001F serialization)
│   │   └── drama_mapper.dart                # Drift Row <-> Drama domain mapper
│   ├── remote/
│   │   ├── tmdb_api.dart                    # Dio TMDB v3/v4 client + TmdbAuthInterceptor + genre map + DTOs
│   │   ├── cloud_sync_repository.dart       # Firestore users/{uid} + chunked backup/chunk_N + realtime sync listener
│   │   └── watch_circle_repository.dart     # Firestore social_profiles, invite_codes, circle_members, nudges
│   └── repository/
│       └── drama_repository_impl.dart       # Local DB + 7-day detail cache + 30-min Discover/Search memory cache
├── domain/
│   ├── model/
│   │   ├── drama.dart                       # Drama model + genreList/tagList/progressFraction/isPartiallyDone + JSON
│   │   ├── drama_extra_details.dart         # DramaExtraDetails, CastMember, SeasonInfo, StreamingProvider, DramaReview
│   │   ├── shortcut.dart                    # Shortcut model
│   │   ├── watch_circle_models.dart         # SharedShowItem, FriendProfile, TasteBlendResult, CoWatchPair, CircleNudge, TasteBlendCalculator
│   │   └── app_settings.dart                # AppSettings, ThemeModeSetting, LibraryLayoutMode, LibrarySortOption, LibraryFilterState
│   └── logic/
│       ├── library_filter.dart              # Pure Dart filtering, sorting, LWW merge, CSV export/import & airing countdown
│       ├── season_progress.dart             # resolveSeasonBreakdown, season-scoped stepper, binge calculator
│       ├── stats_calculator.dart            # 13 Prestige Tiers, 12-month activity, streak, Wrapped card Canvas renderer
│       └── version_checker.dart             # Semantic version comparator (including 2-digit patch) + trusted host sanitizer
└── features/
    ├── splash/                              # MoglogStartupSplashScreen (pulsing logo + emerald progress bar)
    ├── onboarding/                          # 3-step paged onboarding + TMDB key validator + HowToGetKey sheet
    ├── library/                             # LibraryScreen, ContinueWatchingSection, PosterGridItem, CompactDramaRow,
    │                                        # SortFilterSheet, DramaContextMenuSheet, Collection Shelves, Multi-Select
    ├── discover/                            # DiscoverScreen (Watch Circle banner, Recent Searches, 4 rails, debounced search)
    ├── detail/                              # DetailScreen (portrait parallax + landscape 2-pane, dynamic tint, ProgressStepperCard,
    │                                        # BingeCalculatorCard, RatingAndNotesCard, WatchProvidersSection, Cast, Similar)
    ├── stats/                               # StatsScreen (Wrapped Hero, PrestigeTiersBottomSheet, Donut/Genre/12m charts,
    │                                        # Release Radar, TV Diary, Gallery save & PNG share)
    ├── social/                              # WatchCircleScreen (Pass Card, Top 4 picker, Nudges, Co-Watch Race, FriendBlendDetailSheet,
    │                                        # JoinWatchCircleSheet, SendNudgeSheet)
    └── settings/                            # SettingsScreen, AccountSettingsScreen, AppearanceSettingsScreen,
                                             # AdvancedSettingsScreen, RecycleBinScreen, AboutScreen, PrivacyScreen,
                                             # ProfilePhotoDialogs (circular pan/zoom cropper + full-screen viewer)
```

---

## 2. State Management Choice: `flutter_riverpod`

- **Justification:** Replaces Kotlin Hilt DI + `ViewModel` + `StateFlow` cleanly with compile-safe dependency injection (`Provider`), reactive streams (`StreamProvider` directly wired to Drift's `watchAllDramas()`), and immutable state notifiers (`Notifier` / `StateNotifier`).
- **Testability:** Every repository and controller can be overridden via `ProviderContainer(overrides: [...])` in unit and widget tests with zero platform dependencies.

---

## 3. Package List

| Purpose | Package | Notes |
|---------|---------|-------|
| State Management & DI | `flutter_riverpod` | Reactive state & DI |
| Routing | `go_router` | `StatefulShellRoute.indexedStack` (4 tabs) + custom iOS slide transitions |
| Encrypted Local SQLite | `drift`, `sqlite3`, `sqlcipher_flutter_libs`, `path_provider`, `path` | Exact 3-table schema (`dramas`, `shortcuts`, `drama_details_cache`) encrypted with SQLCipher 256-bit AES |
| Preferences | `shared_preferences` | 1:1 21-key `AppSettings` parity |
| Hardware Secure Storage | `flutter_secure_storage` | Android Keystore-backed secret storage |
| E2E Backup Crypto | `cryptography`, `crypto` | `PBKDF2(Hmac.sha256(), 600000)` + `AesGcm.with256bits()` + SHA-256 invite code hashing |
| Networking | `dio` | TMDB API v3/v4 client + GitHub update/stats checks |
| Image Loading & Caching | `cached_network_image`, `flutter_cache_manager` | Smooth caching for posters, backdrops, cast & provider logos |
| Dynamic Poster Accent Tint | `image` | Pure-Dart vibrant/dominant swatch extraction from poster bytes & 512×512 circular avatar JPEG encoding |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_app_check`, `google_sign_in` | Connects to same Firebase project when configured; gracefully degrades offline/unconfigured |
| Biometric / PIN Lock | `local_auth` | Face / Fingerprint / Device PIN |
| Background Workers | `workmanager` | Daily Recycle Bin purge + 12h Episode Reminder check |
| Local Notifications | `flutter_local_notifications` | Channels `moglog_episode_reminders` & `watch_circle_notifications` |
| Connectivity | `connectivity_plus` | Online guards for sync/restore/Watch Circle |
| File Picker / Export | `file_picker` | SAF `.moglog` & `.csv` import/export |
| Share & External URLs | `share_plus`, `url_launcher` | Poster/text share, Wrapped PNG share, YouTube/TMDB/Streaming links |
| Media & Camera | `image_picker` | Camera & gallery avatar selection |
| Icons | `lucide_icons_flutter` | Exact 36+ rounded-outline Lucide icons matching `MoglogIcons` |
| Audio & Haptics | `audioplayers`, `vibration` | Plays synthesized 16-bit 44.1kHz mono WAV chime + victory waveform haptic |
| Permissions & Version | `permission_handler`, `package_info_plus`, `intl` | Android 13+ `POST_NOTIFICATIONS`, app version, date formatting |

---

## 4. Data & Cryptography Compatibility Plan

### 4.1 Byte-Compatible E2E Encryption (`MOGLOG_ENC_V1`)
- **KDF:** `PBKDF2WithHmacSHA256`, `600,000` iterations (decrypt clamps `[10_000, 2_000_000]`), 16-byte CSPRNG salt, 256-bit key.
- **Cipher:** `AES/GCM/NoPadding` (`AesGcm.with256bits()`), 12-byte CSPRNG nonce/IV, 128-bit (16-byte) MAC tag.
- **Wire Representation:** JCE `Cipher.doFinal()` concatenates `cipherText || mac.bytes` (last 16 bytes = tag). Our Dart `BackupCryptoEnvelope` appends `secretBox.mac.bytes` on encrypt and splits the trailing 16 bytes as `Mac` on decrypt.
- **AAD:** Exact UTF-8 bytes of `"moglog-backup:v<schemaVersion>:uid=<uid>"` (`uid = "local"` for `.moglog` files, Firebase `uid` for cloud).
- **JSON Envelope:** Exact keys `format`, `schemaVersion`, `kdf`, `kdfIterations`, `salt`, `iv`, `ciphertext`, `uid`, `createdAt` using standard Base64.
- **Verification:** Cross-platform test vectors verified in `test/core/security/backup_crypto_envelope_test.dart` (encrypting with Kotlin-compatible parameters, decrypting Kotlin-generated vectors, validating wrong passphrase, tampered ciphertext, and mismatched AAD UID rejection).

### 4.2 Firestore Wire Compatibility
- Reads & writes the exact collections and field names enforced by `firestore.rules`:
  - `users/{uid}` (strictly excludes `tmdbApiKey`, deletes legacy `dramas` and `tmdbApiKey`)
  - `users/{uid}/backup/chunk_{0..N}` (450,000 char chunks, proactive cleanup of `chunk_{N..N+2}`, empty-library overwrite protection)
  - `users/{uid}/friends/{friendUid}`
  - `social_profiles/{uid}` (sanitized public activity only — never publishes `notes`, `tags`, email, or keys)
  - `social_profiles/{uid}/circle_members/{memberUid}`
  - `social_profiles/{uid}/nudges/{nudgeId}`
  - `invite_codes/{CODE}` (6-char uppercase alphabet `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`)

### 4.3 Side-by-Side Installation & Firebase Safety
- Application ID: `com.skech.moglog.flutter` (coexists safely alongside Kotlin `com.skech.moglog`).
- No secrets copied from Kotlin repo. App initializes Firebase safely via `try { await Firebase.initializeApp(); }` so local-first functionality works immediately even before `flutterfire configure` is run for `com.skech.moglog.flutter`.

---

## 5. Feature-Parity Checklist

| # | Feature Area | Kotlin Reference | Target Flutter Module | Status |
|---|---|---|---|---|
| 1 | Startup Splash Overlay (≥750ms + pulsing logo) | `MainActivity.kt` | `features/splash/` | Done |
| 2 | 3-Step Onboarding + TMDB Validation + Guide Sheet | `OnboardingScreen.kt` | `features/onboarding/` | Done |
| 3 | Design System (Tokens, Inter Type, Squircles, 36 Icons, Components) | `ui/designsystem/*` | `core/design_system/` | Done |
| 4 | Encrypted Local DB (SQLCipher 256-bit, 3 tables, 7-day cache) | `DramaDatabase.kt` | `data/local/app_database.dart` | Done |
| 5 | Settings Store (all 21 keys) & SecureStore | `SettingsStore.kt`, `SecureStore.kt` | `data/local/settings_store.dart`, `core/security/secure_store.dart` | Done |
| 6 | TMDB API v3/v4 Client + 30-min Discover/Search Cache | `TmdbApi.kt`, `DramaRepositoryImpl.kt` | `data/remote/tmdb_api.dart`, `data/repository/drama_repository_impl.dart` | Done |
| 7 | Library Tab (Collapsing Header, Search, 4 Segments, Shelves, Top 4) | `LibraryScreen.kt` | `features/library/` | Done |
| 8 | Continue Watching Rail (`UP NEXT`, Airing Countdown, `+1` + Undo + Celebration) | `ContinueWatchingSection.kt` | `features/library/widgets/continue_watching_section.dart` | Done |
| 9 | Poster Grid (2/3/4 cols) & Compact List (Swipe +1 / Swipe Bin) | `PosterGridItem.kt`, `CompactDramaRow.kt` | `features/library/widgets/` | Done |
| 10 | Context Menu Sheet, Sort & Filter Sheet, Multi-Select Bulk Actions | `DramaContextMenu.kt`, `SortFilterSheet.kt` | `features/library/widgets/` | Done |
| 11 | Discover Tab (Watch Circle Banner, Recent Searches, 4 Rails, Live Search, Quick Add) | `DiscoverScreen.kt` | `features/discover/` | Done |
| 12 | Detail Screen (Portrait Parallax + Landscape 2-Pane, Dynamic Poster Tint) | `DetailScreen.kt` | `features/detail/` | Done |
| 13 | Multi-Season Progress Stepper + Auto-Advance + Binge Calculator | `ProgressStepperCard.kt`, `DetailScreen.kt` | `features/detail/widgets/` | Done |
| 14 | Rating Slider, Personal Notes/Tags, TMDB Audience Reviews | `RatingAndNotesCard.kt` | `features/detail/widgets/` | Done |
| 15 | Regional Watch Providers (13 Curated Apps, Installed Priority, `nflx://`, Region Fallback) | `WatchProvidersSection.kt` | `features/detail/widgets/` | Done |
| 16 | Show Completion Celebration (85-particle Confetti, PCM WAV Chime, Victory Haptic) | `ShowCompletionCelebration.kt` | `core/celebration/` | Done |
| 17 | Stats Tab (13 Prestige Tiers, Wrapped Hero, Donut/Genre/12m Charts, Radar, Diary) | `StatsScreen.kt` | `features/stats/` | Done |
| 18 | Wrapped Card 1080×1350 PNG Render + Save to Gallery + Share | `StatsScreen.kt` | `domain/logic/stats_calculator.dart` | Done |
| 19 | Watch Circle Social (Pass Card, Rotate Code, Top 4 Picker, Nudges, Co-Watch Race, Taste Blend) | `WatchCircleScreen.kt`, `WatchCircleRepository.kt` | `features/social/`, `data/remote/watch_circle_repository.dart` | Done |
| 20 | Settings Hub + Account & Cloud Sync (E2E Backup, Chunked Restore, Realtime Listener, Delete Account) | `SettingsScreen.kt`, `AccountSettingsScreen.kt`, `CloudSyncRepository.kt` | `features/settings/`, `data/remote/cloud_sync_repository.dart` | Done |
| 21 | Profile Photo Circular Cropper (512×512 Base64) & Photo Viewer | `ProfilePhotoDialogs.kt` | `features/settings/widgets/profile_photo_dialogs.dart` | Done |
| 22 | Appearance Settings (Theme, Dynamic Tint, Grid/List, Density) | `AppearanceSettingsScreen.kt` | `features/settings/appearance_settings_screen.dart` | Done |
| 23 | Advanced & Storage (App Lock, Timeout, `FLAG_SECURE`, `.moglog`/CSV Export & Import, Cache) | `AdvancedSettingsScreen.kt` | `features/settings/advanced_settings_screen.dart` | Done |
| 24 | Recycle Bin (30-day countdown, Swipe Restore/Delete, Empty Bin) | `RecycleBinScreen.kt` | `features/settings/recycle_bin_screen.dart` | Done |
| 25 | About (Live Downloads, GitHub Release Update Checker) & Privacy Screen | `AboutScreen.kt`, `PrivacyScreen.kt` | `features/settings/` | Done |
| 26 | App Lock Overlay (Biometric/PIN, Timeout, Background Privacy Shield) | `AppLockOverlay.kt` | `core/security/app_lock_overlay.dart` | Done |
| 27 | Background Workers (Daily Recycle Bin Purge + 12h Episode Reminder) & Notifications | `RecycleBinPurgeWorker.kt`, `EpisodeReminderWorker.kt` | `core/background/`, `core/notifications/` | Done |
| 28 | Android Platform Parity (`FLAG_SECURE`, 60–120Hz High Refresh Rate, `<queries>`, MediaStore) | `MainActivity.kt`, `AndroidManifest.xml` | `android/app/src/main/kotlin/.../MainActivity.kt` | Done |
