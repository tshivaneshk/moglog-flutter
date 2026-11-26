# Changelog — Moglog Flutter Rewrite

All notable changes to the Flutter migration of Moglog (`D:\Antigravity\Moglog\moglog-flutter`) are recorded in this file.

## [Unreleased]

### Phase 1 — Read-Only Kotlin App Audit
- Audited the entire Kotlin Moglog v3.0.73 codebase (`C:\Users\tshiv\AndroidStudioProjects\Moglog`) in strictly read-only mode.
- Produced `docs/MIGRATION_AUDIT.md` covering all 13 screens, dialogs/sheets, navigation graph, Room v7 / SQLCipher / DataStore / Firestore data layer, `MOGLOG_ENC_V1` E2E encryption specification, Watch Circle social protocol, 13-tier Prestige Stats & Wrapped card generator, background workers, notifications, design tokens, assets, library mappings, and Android-specific platform channel requirements.

## [3.1.2] - 2026-11-26
### Security & Reliability
- **Enterprise Cryptography Upgrade:** Replaced legacy `flutter_secure_storage` v9 (`AES/CBC/PKCS7Padding`) with `flutter_secure_storage` v11 (`AES/GCM/NoPadding` + `RSA/ECB/OAEPWithSHA-256AndMGF1Padding`) and seamless one-time on-device secret migration.
- **APK & Manifest Hardening:** Disabled APK v1 JAR signing (Janus fix, v2/v3 only), stripped unused Firebase web-auth exported activities and permissions, excluded encrypted DB/keystore files from Android backups, stripped release logs and unreachable API-29 `BiometricPrompt` CBC stubs via R8, and enabled Dart symbol obfuscation (`--obfuscate --split-debug-info`).
- **App Lock, SQLCipher & Cloud Sync Fixes:** Fixed biometric lockout fail-open bypass in `AppLockOverlay`, switched lock timeout to monotonic `Stopwatch`, enabled SQLCipher encryption & `cipher_memory_security` on both Android and iOS, hardened `BackupCryptoEnvelope` KDF/format validation, reduced Firestore chunk size with stale-chunk cleanup, and batched multi-select operations.
- **iOS & Xcode CI Verified:** Added `PrivacyInfo.xcprivacy`, `NSPhotoLibraryAddUsageDescription`, Apple App Check (`appAttestWithDeviceCheckFallback`), and iOS notification/share-sheet support; verified on macOS Swift & Xcode GitHub Actions.

## [3.1.0] - 2026-11-22
### Changed — Official Cutover from Native Kotlin (`v3.0.73`) to Flutter (`v3.1.0`)
- **Official App Identity & Seamless In-Place Upgrade:**
  - Switched `applicationId` & Android `namespace` to `com.skech.moglog`, launcher label to **Moglog**, and version to **`3.1.0+14`** (`versionCode 14` > Kotlin's `13`).
  - Configured release signing in `android/app/build.gradle.kts` to use the exact same release keystore via git-ignored `android/local.properties` / environment variables so existing `v3.0.73` users can update directly in-place without uninstalling.
- **One-Time On-Device Kotlin Data Migrator (`LegacyKotlinMigration.kt`):**
  - Automatically detects an existing Kotlin `v3.0.x` install on first launch, decrypts Google Tink `moglog_secure_store` (TMDB key, backup passphrase, DB key), imports all 21 Jetpack DataStore preferences (`moglog_settings.preferences_pb`), and migrates all rows from SQLCipher `/databases/drama_db` (`dramas`, `shortcuts`, `drama_details_cache`) into Flutter's encrypted database before opening the UI.
- **Killed-Process Android `WorkManager` Reminders (`EpisodeReminderWorker.kt`):**
  - Added native Android `WorkManager` 12-hour periodic `EpisodeReminderWorker` with rich `BigPictureStyle` notifications and deep-link routing so episode reminders fire even when Moglog is swiped closed.

## [3.0.73-flutter] - 2026-11-22
### Added
- **Phase 2 (`docs/MIGRATION_PLAN.md`):** Complete feature-first Clean Architecture plan, Riverpod state architecture, package matrix, and `MOGLOG_ENC_V1` + Firestore wire compatibility specification.
- **Phase 3 (Complete 1:1 Flutter Implementation in `com.skech.moglog.flutter`):**
  - Core Design System: Dark (true OLED `#000000`) + Light tokens, bundled Inter variable font on iOS type scale, squircle `SmoothRoundedRectangleBorder`, 36+ Lucide icons, spring-press haptics, and full iOS component library.
  - Security & Data Layer: SQLCipher 256-bit AES local database (`dramas`, `shortcuts`, `drama_details_cache`), `SecureStore` (Keystore-backed), byte-compatible `BackupCryptoEnvelope` (`MOGLOG_ENC_V1`, PBKDF2-HMAC-SHA256 600,000 iterations + AES-256-GCM + UID AAD), all 21 `AppSettings` keys, TMDB v3/v4 API client with 7-day detail cache and 30-minute Discover/Search memory cache.
  - Cloud Sync & Watch Circle: Wire-compatible Firestore `users/{uid}`, chunked `users/{uid}/backup/chunk_N`, `social_profiles`, `invite_codes`, `circle_members`, `nudges`, realtime sync listener, empty-library overwrite guard, Taste Blend calculator, Co-Watch Episode Race, Top 4 Favorites showcase.
  - All 13 Screens & Overlays: Startup Splash, 3-Step Onboarding, Library (Continue Watching, Grid/List, Swipe actions, Collection Shelves, Sort & Filter, Context Menu, Multi-Select), Discover (Watch Circle Banner, Recent Searches, 4 Rails, Live Search), Detail (Portrait Parallax + Landscape 2-Pane, Dynamic Poster Tint, Multi-Season Stepper, Binge Calculator, Rating/Notes/Reviews, Regional Watch Providers with 13 curated apps, Cast, Similar Shows), Stats (13 Prestige Tiers, Wrapped Hero, 1080x1350 PNG Wrapped Card Gallery Save & Share, Donut/Genre/12m Charts, Release Radar, TV Diary), Watch Circle, Settings Hub, Account & Cloud (with WhatsApp-style 512x512 Circular Cropper & Photo Viewer), Appearance, Advanced & Storage (`.moglog`/CSV export & import), Recycle Bin, About (live downloads & GitHub update checker), Privacy, App Lock Overlay, Celebration Confetti + PCM Chime + Victory Haptic.
  - Android Platform Parity: `MainActivity.kt` (`FlutterFragmentActivity`) with `FLAG_SECURE`, 60–120Hz display refresh rate negotiation, curated 13 streaming app detection & `nflx://` deep links, MediaStore gallery saving, and synthesized PCM AudioTrack chime.
- **Phase 4 (Verification & Tests):**
  - 25 unit & widget tests covering `MOGLOG_ENC_V1` crypto vectors, filtering/sorting/LWW merge, CSV injection defense & TV Time/Trakt parsing, 13 Prestige Tiers, Taste Blend, version checker, SQLite CRUD + 30-day Recycle Bin purge, and key screens.
  - `flutter analyze`: 0 issues; `flutter test`: 25/25 passing.

### Changed / Fixed
- **Firebase & Google Sign-In:** Updated `android/app/google-services.json` (git-ignored) with the Android OAuth client (`client_type: 1`) SHA-1 registration for `com.skech.moglog.flutter`.
- **1:1 Kotlin Parity — Personal Notes & Tags Removed:** Replaced the Personal Notes & Tags inputs in `RatingAndNotesCard` / `DetailScreen` / `LibraryScreen` with Kotlin's exact My Rating (with `Clear` button) + Audience Reviews & Google Reviews card.
- **120Hz Scroll & Render Optimization:**
  - Removed full-screen `DetailScreen` `setState` rebuilds on every scroll pixel (replaced with scoped `AnimatedBuilder` for parallax header).
  - Removed live `ImageFilter.blur` `BackdropFilter` from `IosFrostedBar` (matching Kotlin's translucent surface without per-frame GPU blur overdraw).
  - Added DPR-scaled `memCacheWidth` / `memCacheHeight` sizing to `PosterImage` and `onWindowFocusChanged` 120Hz display mode enforcement in `MainActivity.kt`.
- **Release Build R8 / ProGuard Fix:** Added `android/app/proguard-rules.pro` and enabled it in `android/app/build.gradle.kts` (`isMinifyEnabled = true`, `isShrinkResources = true`) so R8 keeps `androidx.room.RoomDatabase` / `androidx.work.impl.WorkDatabase_Impl` constructors, `androidx.startup.Initializer`, SQLCipher, Google Auth, and Firebase classes in release APKs. Verified `app-release.apk` (81.8 MB) installs and launches cleanly on emulator with zero crashes.
- **UI Alignment, Bottom Sheet Layering, Version & Instant Poster Tint:**
  - Fixed `showIosBottomSheet` (`useRootNavigator: true` + `maxHeight: 0.84 * height`) so `Sort & Filter` and `ActionSheet` dialogs render above the bottom tab bar and below the status bar / punch-hole.
  - Centered all 3 onboarding steps vertically and horizontally matching Kotlin `OnboardingScreen`, and removed the leftover `"notes"` mention from onboarding feature copy.
  - Updated Settings **Version** row to display only the version number (`3.0.73`), matching Kotlin `SettingsScreen`.
- **1:1 UI, Tech-Stack Disclosure & Scroll Polish:**
  - **Instant Native Poster Tint:** Replaced slow `Isolate` + `package:image` JPEG decoding with synchronous `getImmediateDramaById` lookup + native hardware-decoded `ResizeImage(CachedNetworkImageProvider, width: 24)` (`~2ms`) and animated hero gradient & accent glow transitions.
  - **Library Status Tab Numbers (`Watching`, `Planned`):** Updated `IosSegmentedControl` to Kotlin's responsive width-based font scaling (`9.5sp–13sp`) + `FittedBox(fit: BoxFit.scaleDown)` so counts like `Watching (X)` and `Planned (XXX)` never truncate with ellipses.
  - **Centered Collapsed Navbar Titles & Pinned Library Controls:** Fixed `IosLargeTitleHeader` to horizontally center `"Library"`, `"Discover"`, `"Stats"`, `"Settings"` when scrolled (via balanced `Stack`), pinned Library Search/Status/Shelves in `IosLargeTitleHeader.bottomContent` matching Kotlin, and added crisp frosted blur on `IosBottomTabBar`.
  - **Single-Line Copy & Tech Stack Behind `'i'` Icon:** Shortened subtitles across Settings, Account, Advanced, Privacy, Onboarding, Sort/Filter, and Export sheets to crisp single-line text and tucked technical implementation details (`SQLCipher`, `PBKDF2`, `AES-256-GCM`, `FLAG_SECURE`, `Keystore`) inside tap-to-open `'i'` info sheets (`IosInfoButton`).
  - **Show Share Format:** Unified `buildShowShareText` across Detail and Library sheets to share under `Track With Moglog` with the instruction webpage link (`https://moglog-instructions.vercel.app`).
- **Import / Export Progress, Poster Preloading & Circular Cast Avatars:**
  - **Import / Export Feedback & Loading Dialog:** Added live progress dialogs for backup export and import (showing metadata & poster download counts), captured root `toastProvider` safely across async SAF pickers, and displayed `"X shows loaded into library"` / `"Exported X shows"` for 4 seconds.
  - **Complete CSV Metadata & Poster Caching:** Removed the 35-show TMDB lookup cap on CSV imports, added concurrent pool fetching + disk poster pre-warming (`DefaultCacheManager`) with retry, normalized relative `/poster.jpg` URLs, and added automatic transient-error retries to `PosterImage`.
  - **Perfect Circle Cast Avatars:** Removed square height distortion in `PosterImage` (`memCacheHeight` omitted) and enforced `SizedBox.square(64)` + `ClipOval` with portrait face alignment for Cast photos.
  - Added in-memory `_posterTintCache`, disk cache lookup via `DefaultCacheManager`, tiny `/w92/` fallback, and background `Isolate.run` palette extraction for near-instant dynamic poster tinting, and restored standard iOS segmented control pill styling.
- **Pop-up Window & Landscape Parity:** Added `<layout>` freeform window size hints (`minWidth="200dp"`, `minHeight="240dp"`) to `AndroidManifest.xml`, compact pop-up collapse logic to `IosLargeTitleHeader`, side-by-side landscape Search + Status bar & adaptive grid to `LibraryScreen`, 2-pane landscape actions to `DetailScreen`, and `maxWidth: 780` centering to `WatchCircleScreen`.
