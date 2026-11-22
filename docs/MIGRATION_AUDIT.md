# Moglog Kotlin-to-Flutter Migration Audit

- **Source Project (Read-Only):** `C:\Users\tshiv\AndroidStudioProjects\Moglog`
- **Package / Application ID (Kotlin):** `com.skech.moglog` (Version `3.0.73`, `versionCode = 13`, `minSdk = 29`, `compileSdk = 35`, `targetSdk = 35`)
- **Target Project (Flutter):** `D:\Antigravity\Moglog\moglog-flutter` (Distinct application ID proposed: `com.skech.moglog.flutter`)
- **Audit Scope:** Complete read-only audit of all Kotlin source files, Gradle configurations, AndroidManifest, XML configs, Firestore rules, resources, and unit tests.

---

## 1. Full Feature Inventory

### 1.1 Screens (13 Routes)

| # | Screen | Kotlin File | Purpose & Key Capabilities |
|---|--------|-------------|----------------------------|
| 1 | **Startup Splash Overlay** | `MainActivity.kt` (`MoglogStartupSplashScreen`) | Android 12+ `Theme.App.Starting` (`#05050A`) transitioning into an in-app pulsing logo (`app_logo2`, 86dp, scale `0.96..1.04`, 1200ms reverse) + emerald `LinearProgressIndicator`. Holds until first Room emission completes AND ≥ 750ms elapsed, then fades out (380ms). |
| 2 | **Onboarding (3-step paged)** | `ui/onboarding/OnboardingScreen.kt` | Shown only when `settings.isFirstLaunch == true`. Step 0: Welcome, Moglog wordmark, 3 feature highlights. Step 1: TMDB v3 API key (32 hex) / v4 JWT Read Access Token entry, clipboard paste, format validation, inline "How to get a free TMDB key" bottom sheet. Step 2: Optional Google Sign-In for E2E cloud backup. Skip button available on all steps. |
| 3 | **Library (Tab 1)** | `ui/library/LibraryScreen.kt` | Main watchlist hub. Collapsing iOS Large Title header, search bar (title/notes/tags), 4-segment status control (`All`, `Watching`, `Planned`, `Done`) with live count on active segment, horizontal custom Collection Shelves + `Top 4 Favorites` chip row (tap to filter, long-press shelf to rename/delete, `+ New Shelf` button), pinned **Continue Watching** horizontal rail (on `All` tab with no search) with `UP NEXT · SxxExx`, live airing countdown badge (`AIRS TODAY`, `TOMORROW`, `IN xD`, `MMM d`), remaining time estimate, and one-tap `+1` episode button with Undo toast + completion celebration (audio chime + waveform haptic + 85-particle confetti canvas). Supports Poster Grid (2/3/4 columns, adaptive in landscape/pop-up) and Compact List rows (swipe right = `+1 Ep`, swipe left = Move to Recycle Bin). Long-press opens `DramaContextMenuSheet`; multi-select mode allows bulk status change and bulk soft-delete. |
| 4 | **Discover (Tab 2)** | `ui/discover/DiscoverScreen.kt` | TMDB catalog explorer. Collapsing header with Watch Circle quick-access button (with unread nudges dot) and Refresh button. Debounced (450ms) live TMDB TV search with shimmer skeleton & empty states. Idle state displays: **Watch Circle & Blend** promo/status banner (overlapping friend avatars, live friend watching preview), **Recent Searches** (up to 5 shown, 8 stored, Clear button), and 4 horizontal poster rails (**Trending This Week**, **Popular Right Now**, **Airing Today**, **Currently On The Air**). Inline `+` quick-add to `Planned` (switches to checkmark when in library). Missing TMDB key state shows CTA to Settings. |
| 5 | **Detail Screen** | `ui/detail/DetailScreen.kt` | Adaptive portrait (full-bleed parallax poster header `translationY = -scroll * 0.35`, height 48% clamped `190..440dp`, vertical gradient blend) and landscape (2-pane 34%/66% split). Optional dynamic poster accent tint via `androidx.palette`. Displays In-Library & Hidden-from-Circle badges, Title, TMDB rating/year/seasons/genres, quick action pills (`Pin to Top 4`, `Add to Shelf` / `Shelves (n)`), adaptive season-aware Status Segmented Control (`S{n} Watching/Planned/Done`), `ProgressStepperCard` (season-scoped episode stepper, completed season `✓ S#` chips, auto-advance season, auto-promote `Planned → Watching`, completion celebration on final episode, next episode air-date banner), `BingeCalculatorCard` (remaining time, days to finish at 1/2/3/5 ep/day pace), expandable Overview + Watch Trailer (YouTube) + Search Web (Google), `RatingAndNotesCard` (0–10 half-step personal rating slider + TMDB Audience Reviews with expandable text + Google Reviews shortcut), `WatchProvidersAndShortcutSection` (regional JustWatch/TMDB providers sorted with installed streaming apps first, curated direct app/web deep-links, region fallback badge), Cast horizontal rail (up to 12), Similar/Recommended Shows rail (up to 12), sticky bottom `Add to Library` bar for unsaved shows (autosaves after 350ms debounce once in library). |
| 6 | **Stats (Tab 3)** | `ui/stats/StatsScreen.kt` | Apple-Health-style analytics dashboard. Top actions: Save Wrapped Card to Gallery (`MediaStore`, `Pictures/Moglog`, 1080×1350 PNG) and Share Wrapped Card (`FileProvider` PNG + text). Content: **Moglog Wrapped Hero Card** (13-tier Prestige Rank system with dynamic color, rank progress bar, clickable to open `PrestigeTiersBottomSheet`), 4 Summary Metric cards (`Total Shows`, `Episodes`, `Est. Hours` + days, `Monthly Streak`), **Status Breakdown** animated Donut Chart + legend, **Top Genres** horizontal bar chart (top 6), **12-Month Activity** bar chart, **Your Highest Rated** top 5 list, **Release Radar · Airing Schedule** (up to 8 upcoming `Watching`/`Planned` shows with countdown badges), and **TV Diary Timeline** (7 most recent activity entries). Landscape adapts metrics to 1×4 row and Status+Genre side-by-side. |
| 7 | **Settings Hub (Tab 4)** | `ui/settings/SettingsScreen.kt` | One UI / iOS inset-grouped settings hub. Top Hero Profile Card (custom Base64 avatar or Google avatar, display name, email/sign-in prompt → Account screen). Sections: **Connected Services** (`Watch Circle & Friends` count + `Share My Watch Activity` switch when signed in), **Preferences** (`Appearance`, `Advanced & Storage`), **Notifications** (`Episode Air-Date Reminders` switch with Android 13+ `POST_NOTIFICATIONS` runtime permission request), **About** (`About` + read-only `Version`). |
| 8 | **Account & Cloud Settings** | `ui/settings/AccountSettingsScreen.kt` | Hero identity card (80dp avatar with `+` badge, display name, email, `Edit Profile & Name` pill). Signed-out: `Sign In with Google`. Signed-in: `Back Up Now` (with empty-library safety check against cloud shows), `Restore from Cloud`, `End-to-End Encrypted Backup` switch (prompts passphrase if unset), `Backup Passphrase` row (`Configured`/`Not Set`), `Sign Out`, `Delete Cloud Account & Data` (option to keep local or 2-step permanent wipe). |
| 9 | **Appearance Settings** | `ui/settings/AppearanceSettingsScreen.kt` | `Theme` segmented control (`System`, `Dark`, `Light`), `Dynamic Poster Accent Tint` switch, `Default Library View` toggle (`Poster Grid` / `Compact List`), `Poster Grid Density` cycler (`2` → `3` → `4` → `2 Columns`). |
| 10 | **Advanced & Storage Settings** | `ui/settings/AdvancedSettingsScreen.kt` | **App Security**: `Biometric / Device PIN Lock` switch, `Lock Timeout` selector (`Immediately` 0s / `After 1 minute` 60s / `After 5 minutes` 300s), `Hide in App Switcher` (`FLAG_SECURE`) switch. **Data & Storage**: `Export Library Backup` (`.moglog` AES-256-GCM or `.csv`), `Import Library Backup` (`.moglog` or `.csv` including TV Time / Trakt), `Recycle Bin` (with deleted count), `Clear Metadata Cache`. **TMDB API Integration**: `TMDB API Key / Read Token` (`Configured`/`Not Set`), `How to Obtain Your API Key` external guide link. |
| 11 | **Watch Circle (Social)** | `ui/social/WatchCircleScreen.kt` | Signed-out feature pitch + Google Sign-In CTA. Signed-in: **My Watch Circle Pass Card** (avatar, name, sharing status, monospace 6-char Circle Code pill — tap to copy, long-press to CSPRNG-rotate — `Share Group Link`, `Enter Friend Code`, **My Top 4 All-Time Favorites** 4-slot poster showcase with `+ Add` picker and long-press unpin, `Share My Watch Activity` toggle), **Incoming Nudges & Reactions** (up to 4 cards with icon, sender, show, message, dismiss `×`), **Co-Watching Episode Race** (up to 4 head-to-head progress bar comparisons with episode delta & quick nudge button), **Circle Members Feed** (`FriendActivityCard` with Taste Blend `% Match` pill, badge title, shared shows/genres, horizontal poster shelf with episode badge, quick nudge & quick `+` add to Planned). |
| 12 | **Recycle Bin** | `ui/settings/RecycleBinScreen.kt` | Lists soft-deleted shows (`isDeleted == true`) with days remaining before 30-day auto-purge. Supports swipe right to Restore, swipe left to Delete Forever, inline Restore/Delete icon buttons, and `Empty` header button with confirmation sheet. |
| 13 | **Privacy & Security** & **About** | `ui/settings/PrivacyScreen.kt`, `ui/settings/AboutScreen.kt` | **Privacy:** Static architecture disclosure (SQLCipher, Tink, Auto-Backup exclusion, E2E cloud backup, TMDB & Firebase disclosures). **About:** Branding, version, Developer link (`moglog-instructions.vercel.app`), GitHub Releases link with live download counter (fetched from `moglog-instructions.vercel.app/api/badge?format=json` with fallback to GitHub Releases API), Report an Issue link, **Check for Updates** (queries GitHub Releases latest tag, semantic version comparison including 2-digit patch handling, trusted-host URL sanitizer, Download Latest APK & View Release Notes buttons), Privacy link, TMDB Terms of Use. |

### 1.2 Overlays, Dialogs, Bottom Sheets & Menus

| Component | File | Trigger & Behavior |
|-----------|------|--------------------|
| `AppLockOverlay` | `ui/security/AppLockOverlay.kt` | Full-screen privacy shield shown on cold start (when `appLockEnabled`), when backgrounded (`ON_PAUSE` if `appLockEnabled || hideInRecents`), and after `ON_STOP` → `ON_RESUME` elapsed ≥ `timeoutSeconds`. Invokes `BiometricPrompt` (`BIOMETRIC_STRONG | BIOMETRIC_WEAK | DEVICE_CREDENTIAL`). Auto-unlocks if no device credential/biometric is enrolled. |
| `CreateAccount` Action Sheet | `MoglogNavHost.kt` | Shown when Google Sign-In succeeds for a UID with no `users/{uid}` Firestore doc. Confirms initializing cloud backup or signs back out on cancel. |
| `HowToGetKey` Sheet | `OnboardingScreen.kt` | Visual Setup Guide (`moglog-instructions.vercel.app/obtain-api-key`), TMDB signup link, instructions. |
| `SortFilterSheet` | `ui/library/SortFilterSheet.kt` | 7 Sort options, `Partially Done Series` toggle, Minimum Rating (`Any`, `7.0+`, `8.0+`, `9.0+`), Genre multi-select `FlowRow` (18 preset + library genres), Apply & Reset. |
| `DramaContextMenuSheet` | `ui/library/DramaContextMenu.kt` | Long-press on Library poster/row: Preview header, inline status segmented control, 5-star quick rating (`2.0..10.0`), `+1 Ep`, Share, Select Shows (enters multi-select), Move to Recycle Bin. |
| Collection Shelf Dialogs | `LibraryScreen.kt` | `AlertDialog` for New Collection Shelf (max 28 chars), `IosActionSheet` for Shelf Options (Rename/Delete on long-press), Rename `AlertDialog`, Delete Confirmation `AlertDialog`. |
| Bulk Status Sheet | `LibraryScreen.kt` | Multi-select mode → `Status` → `IosActionSheet` (`Watching`, `Planned`, `Done`). |
| Detail Sheets | `DetailScreen.kt` | `More` action sheet (Share with poster image, Open on TMDB, Hide/Unhide from Watch Circle, Move to Recycle Bin), `Assign to Collection Shelf` action sheet, `Promote to Done` action sheet. |
| `CelebrationBlastOverlay` | `ui/celebration/ShowCompletionCelebration.kt` | 85-particle 1800ms canvas confetti explosion + synthesized 3-tone PCM audio arpeggio (C6→E6→G6) + multi-pulse victory vibration waveform. *(Note: `ShowCompletionCelebrationDialog` is also defined in this file but currently not wired into callers.)* |
| `PrestigeTiersBottomSheet` | `StatsScreen.kt` | Shows all 13 Prestige Tiers, current rank banner, unlock criteria, hours range, and locked/unlocked status. |
| `ProfileImageCropDialog` | `ui/settings/ProfilePhotoDialogs.kt` | Full-screen WhatsApp-style circular pan/pinch-to-zoom cropper (`1x..4.5x`), exports 512×512 JPEG (quality 85) as Base64. |
| `ProfilePhotoViewerDialog` | `ui/settings/ProfilePhotoDialogs.kt` | Full-screen dark viewer for current profile photo (Base64 or Google photo URL). |
| Account & Advanced Sheets | `AccountSettingsScreen.kt`, `AdvancedSettingsScreen.kt` | Empty-Library Cloud Warning, Sign Out confirmation, Delete Account (2 options + 2nd destructive confirmation), Profile Photo source sheet (View, Camera via `FileProvider`, Gallery, Edit Display Name, Remove), Edit Display Name sheet (max 40 chars), E2E Backup Passphrase sheet (min 6 chars, show/hide), App Lock Timeout sheet, Export Mode sheet (`.moglog` / `.csv`), Import Mode sheet (`.moglog` / `.csv`), Decrypt Backup Passphrase sheet, TMDB Credential sheet (show/hide, validation, remove). |
| Watch Circle Sheets | `WatchCircleScreen.kt` | `PickFavoriteSheet` (searchable library picker for Top 4), `Top 4 Favorite` long-press action sheet (Open / Unpin), `JoinWatchCircleSheet` (6-char uppercase monospace input + smart clipboard code extractor), `FriendBlendDetailSheet` (animated Taste Blend ring, shared vibes, Top 4 posters, 3 tabs: Watching / In Common / Top Done, quick nudge & quick add, Remove Friend), `Remove Friend` confirmation, `SendNudgeSheet` (5 preset reactions: `FIRE`, `WAIT`, `PACE`, `AWARD`, `SPARK`). |
| `IosToastBanner` | `ui/designsystem/Components.kt` | Floating pill toast with optional action button (e.g., `Undo`), auto-dismissed after 2.5–3.8s. |

### 1.3 Widgets, Deep Links, Notifications & Background Jobs

- **Home-Screen Widgets:** **None present in v3.0.73.** *(Note: `docs/REDESIGN_NOTES.md` mentions a v2.0 Jetpack Glance `ContinueWatchingWidget`, but no widget code, receiver, or Glance dependency exists in the current Kotlin codebase or `AndroidManifest.xml`.)*
- **Deep Links / Intent Extras:**
  - No custom URL scheme `<intent-filter>` in `AndroidManifest.xml` (only `MAIN`/`LAUNCHER`).
  - Internal notification-tap extras handled by `MainActivity.extractDeepLinkIntent` (`onCreate` & `onNewIntent`):
    - `open_drama_id` (Int > 0) → navigates to `MoglogRoutes.Detail(dramaId)`
    - `navigate_to` (`"watch_circle"`) → navigates to `MoglogRoutes.WatchCircle`
- **Notifications & Channels:**
  1. `moglog_episode_reminders` (**"Episode Air-Date Reminders"**, `IMPORTANCE_HIGH`, emerald light `#30D158`): Posted by `EpisodeReminderWorker` with custom small icon `ic_stat_moglog`, `BigPictureStyle` poster bitmap (fallback `BigTextStyle` overview), `"Log Episode"` action button, taps open `Detail(dramaId)`. Includes helper `sendTestReminderNotification`.
  2. `watch_circle_notifications` (**"Watch Circle Social"**, `IMPORTANCE_HIGH`, emerald light `#2ECC71`): Posted by `WatchCircleRepository` when a new friend joins via `circle_members` Firestore snapshot listener or during `fetchWatchCircle`. Taps open `WatchCircle`.
- **Background Jobs (WorkManager):**
  1. `RecycleBinPurgeWorker` (`moglog_recycle_bin_purge_worker`): Periodic every **1 day** (`ExistingPeriodicWorkPolicy.KEEP`), permanently deletes `dramas` where `isDeleted = 1 AND deletedAt > 0 AND deletedAt < now - 30d`.
  2. `EpisodeReminderWorker` (`moglog_episode_reminder_worker`): Periodic every **12 hours** (`NetworkType.CONNECTED`, `KEEP`), plus one-time immediate check when enabled. Checks active `Watching` shows against today's ISO date (`yyyy-MM-dd`) by calling `getDramaExtraDetails(id)` and posts notifications for matches.

---

## 2. Navigation Graph & User Flows

```
[App Launch]
   │
   ├─► Splash Overlay (holds ≥750ms + first DB emission)
   ├─► AppLockOverlay (gates entire UI if appLockEnabled or backgrounded)
   │
   ├─► (isFirstLaunch == true) ─► Onboarding (3 steps) ─► replaces stack with Library
   │
   └─► Main 4-Tab Shell (IosBottomTabBar visible ONLY on these 4 routes; state saved/restored per tab)
         ├── Library ─────────────────────────► Detail(dramaId) ──► Detail(recommendedId) [recursive]
         │     └── (+) button ────────────────► Discover
         ├── Discover ────────────────────────► Detail(dramaId)
         │     ├── Missing key CTA ───────────► Settings
         │     └── Watch Circle icon/banner ──► WatchCircle ──► Detail(dramaId)
         ├── Stats ───────────────────────────► Detail(dramaId)
         └── Settings
               ├── Hero Profile Card ─────────► SettingsAccount
               ├── Watch Circle row ──────────► WatchCircle
               ├── Appearance row ────────────► SettingsAppearance
               ├── Advanced & Storage row ────► SettingsAdvanced ──► RecycleBin
               └── About row ─────────────────► About ──► Privacy
```

**Transitions:**
- Between top-level tabs: Cross-fade (`140ms`).
- Push sub-screens: iOS horizontal slide-in from right (`100% → 0%`, `280ms`) + fade (`180ms`), outgoing screen parallax slides left (`0% → -28%`).
- Pop sub-screens: Reverse parallax (`-28% → 0%`, outgoing `0% → 100%`).

---

## 3. Data Layer

### 3.1 Domain Models & Local SQLite Schema (Room v7, SQLCipher 256-bit AES)

Database name: `drama_db` (encrypted at rest via `sqlcipher-android` 4.6.1 with a 256-bit random key stored in `SecureStore`; crash-safe plaintext→SQLCipher migration via `SqlCipherMigrationHelper`).

#### Table 1: `dramas` (`DramaEntity` ↔ `Drama`)
| Column | SQL Type | Default | Notes |
|--------|----------|---------|-------|
| `id` | INTEGER PK | — | TMDB TV show ID (or hash for unmatched CSV rows) |
| `title` | TEXT | — | Show title |
| `overview` | TEXT | — | Synopsis |
| `rating` | REAL | — | TMDB `vote_average` (0.0–10.0) |
| `posterPath` | TEXT | — | Full URL `https://image.tmdb.org/t/p/w500/...` or empty |
| `status` | TEXT | `"Planned"` | `"Planned"`, `"Watching"`, `"Done"` |
| `episodesWatched` | INTEGER | `0` | Global cumulative episodes watched |
| `totalEpisodes` | INTEGER | `0` | Total series episodes |
| `isDeleted` | INTEGER (Bool) | `0` | Soft-delete flag (Recycle Bin) |
| `addedAt` | INTEGER | `0` | Epoch ms |
| `updatedAt` | INTEGER | `0` | Epoch ms (used for Last-Write-Wins merge) |
| `completedAt` | INTEGER | `0` | Epoch ms (set when transitioning into `"Done"`) |
| `myRating` | REAL | `0.0` | User rating `0.0`–`10.0` (0.5 increments) |
| `notes` | TEXT | `""` | Preserved in DB/JSON/search |
| `tags` | TEXT | `""` | Comma-separated tags (used for Custom Collection Shelves) |
| `genres` | TEXT | `""` | Comma-separated TMDB genre names |
| `releaseYear` | INTEGER | `0` | Parsed from `first_air_date` |
| `totalSeasons` | INTEGER | `0` | Number of seasons |
| `currentSeason` | INTEGER | `1` | Active season (1-based) |
| `currentEpisode` | INTEGER | `0` | Mirrors `episodesWatched` |
| `nextEpisodeAirDate` | TEXT (nullable) | `null` | ISO `yyyy-MM-dd` |
| `nextEpisodeNumber` | INTEGER | `0` | Next airing episode number |
| `nextSeasonNumber` | INTEGER | `0` | Next airing season number |
| `deletedAt` | INTEGER | `0` | Epoch ms when moved to Recycle Bin |

*Computed properties on `Drama`:* `genreList`, `tagList`, `progressFraction`, `isPartiallyDone` (`!isDeleted && status != "Done" && !(totalEpisodes > 0 && episodesWatched >= totalEpisodes) && (currentSeason > 1 || (totalSeasons > 1 && totalEpisodes > 0 && episodesWatched >= max(1, totalEpisodes / totalSeasons)))`).

#### Table 2: `shortcuts` (`ShortcutEntity` ↔ `Shortcut`)
`id` (PK autoincrement), `title`, `data` (package/URL), `type` (`"APP"` / `"LINK"`), `iconUrl` (nullable), `dramaId` (Int, default 0). *(Retained for schema compatibility; currently UI uses curated Watch Providers.)*

#### Table 3: `drama_details_cache` (`DramaDetailCacheEntity`)
`dramaId` (PK), `payloadJson` (Gson-serialized `DramaExtraDetails`), `cachedAt` (epoch ms). **7-day TTL** (`604,800,000 ms`); stale cache returned when offline.

### 3.2 Preferences & Secure Storage

- **DataStore (`moglog_settings`):** 21 keys (delimiter `\u001F` for list/set values): `isFirstLaunch` (default `true`), `syncFrequency` (`"On Every Change"`), `themeMode` (`DARK`), `dynamicPosterTint` (`true`), `gridColumns` (`3`, clamped 2–4), `layoutMode` (`GRID`), `appLockEnabled` (`false`), `appLockTimeoutSeconds` (`60`), `hideInRecents` (`false`), `encryptedCloudBackupEnabled` (`false`), `episodeRemindersEnabled` (`false`), `lastSyncedAt` (`0`), `recentSearches` (max 8), `sqlCipherMigrated` (`false`), `customProfileImageBase64` (`""`), `customDisplayName` (`""`), `watchCircleSharingEnabled` (`true`), `hiddenFromCircleDramaIds` (Set<Int>), `topFourFavoriteIds` (max 4 List<Int>), `customCollections` (default `["Comfort Shows", "Weekend Binge", "Must Watch"]`), `customInviteCode` (`""`).
- **SharedPreferences (`moglog_watch_circle_prefs`):** `known_friends_{uid}` (`Set<String>`) for friend-added notifications.
- **Encrypted Storage (`SecureStore` — `moglog_secure_store` + `moglog_tink_keyset_prefs`):** Stores `enc_tmdb_credential`, `enc_db_passphrase`, `enc_backup_passphrase` via Tink AES256_GCM (primary hardware Android Keystore + secondary software fallback keyset to prevent Keystore-reset DB lockouts).

### 3.3 Remote Backend: Firebase Auth & Cloud Firestore

- **Firebase Auth:** Google Sign-In via AndroidX Credential Manager (`GetGoogleIdOption` + `GetSignInWithGoogleOption`, SHA-256 hashed nonce, `GoogleAuthProvider.getCredential`). Updates Firebase user photo URI if provided.
- **Firebase App Check:** `PlayIntegrityAppCheckProviderFactory` (release) / `DebugAppCheckProviderFactory` (debug).
- **Firestore Schema (strictly validated by `firestore.rules` — MUST remain 100% wire-compatible):**
  1. `users/{uid}` (owner read/write/delete; rejects `tmdbApiKey`; max 24 fields):
     - `encryptedBackup` (bool), `backupChunks` (int), `lastSyncedAt` (long ms), `topFourFavoriteIds` (List<Int>), `customCollections` (List<String>), `profileImageBase64` (String ≤ 400k chars, deleted if blank), `customDisplayName` (String ≤ 80, deleted if blank), `customInviteCode` (String ≤ 8, deleted if blank). Explicitly deletes legacy `dramas` and `tmdbApiKey`.
  2. `users/{uid}/backup/chunk_{0..N}` (owner only; `totalChunks ≤ 50`; max 450,000 chars per chunk):
     - **Encrypted mode (`encrypted: true`):** `index`, `totalChunks`, `encrypted`, `format` (`"MOGLOG_ENC_V1"`), `schemaVersion` (`1`), `kdf` (`"PBKDF2WithHmacSHA256"`), `kdfIterations` (`600000`), `salt` (Base64), `iv` (Base64), `ciphertextChunk` (slice of Base64 ciphertext), `updatedAt` (long).
     - **Standard mode (`encrypted: false`):** `index`, `totalChunks`, `encrypted`, `payloadChunk` (slice of Gson JSON array of `Drama`), `updatedAt` (long).
     - Proactively deletes `chunk_{chunks.size .. chunks.size+2}` in the same atomic `WriteBatch`.
     - Safety guard: refuses to overwrite existing non-empty cloud backup when local `dramas` list is empty.
  3. `users/{uid}/friends/{friendUid}`: `{ uid, addedAt }`.
  4. `social_profiles/{uid}` (any signed-in `get`, no `list`; owner write/delete):
     - `uid`, `inviteCode`, `displayName` (≤ 80), `photoUrl`, `photoBase64` (≤ 120k published / ≤ 400k rules), `sharingEnabled`, `updatedAt`, `totalWatched`, `totalEpisodes`, `topGenres` (top 5), `currentlyWatching` (top 15 `SharedShowItem`), `recentlyCompleted` (top 15), `plannedShows` (top 10), `topFourFavorites` (top 4). Strictly omits `notes`, `tags`, email, API keys.
  5. `social_profiles/{uid}/circle_members/{memberUid}`: `{ uid, addedAt }` (owner or joining member can create/delete).
  6. `social_profiles/{uid}/nudges/{nudgeId}`: `{ fromUid, fromName (≤60), dramaId, dramaTitle (≤120), emoji (≤8), message (≤140), createdAt }` (any signed-in create as self; owner read/delete; immutable).
  7. `invite_codes/{CODE}` (6-char `[A-Z0-9]{6}`, alphabet `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`): `{ uid, displayName, updatedAt }`.

### 3.4 Sync Logic, Offline Behavior & Conflict Handling

- **Debounced Auto-Sync:** Every `saveDrama` triggers a 320ms debounced background `syncToCloud` + `watchCircleRepository.publishMyActivity`. Delete / move-to-bin / restore / empty-bin sync immediately.
- **Realtime Sync Listener:** `users/{uid}` Firestore snapshot listener syncs profile metadata (`topFourFavoriteIds`, `customCollections`, `profileImageBase64`, `customDisplayName`, `customInviteCode`) and triggers `reconcileCloudAndLocal()` when `!snapshot.metadata.hasPendingWrites()` and `remoteLastSynced` differs from both `lastLocalSyncTimestamp` and `localLastSynced`.
- **Conflict Resolution (Last-Write-Wins by `updatedAt`):**
  - On cloud reconcile: for each remote drama, if local is missing or `incoming.updatedAt >= existing.updatedAt`, overwrite local; otherwise mark `localNeedsPush = true`. Any local-only drama also sets `localNeedsPush = true`. If `localNeedsPush`, push merged map back to cloud.
  - On file import (`.moglog`): add missing IDs; update existing only if `sanitized.updatedAt > existing.updatedAt`; skip otherwise.
  - On CSV import: merge by TMDB ID or lowercase title; `maxOf(existing.episodesWatched, effectiveEps)`; keep existing `myRating` if > 0; cap live TMDB lookups at 35 shows.
- **Offline Support:** Full local library CRUD works offline via SQLCipher DB. Discover rails and searches cached in-memory for 30 minutes (`DISCOVER_MEMORY_TTL_MS`). Show extra details cached in Room for 7 days (`CACHE_TTL_MS`) with stale fallback on network error. Posters cached via Coil (25% RAM + 150 MB disk cache, ignoring cache headers). Online checks via `ConnectivityManager` gate manual sync/restore/Watch Circle operations.

### 3.5 External REST APIs

1. **TMDB API v3 (`https://api.themoviedb.org/3/`):**
   - Auth via `TmdbAuthInterceptor`: v4 JWT (`eyJ...` with 2 dots) → `Authorization: Bearer <token>`; v3 32-char hex key → `?api_key=<key>`. Always sets `Accept: application/json`.
   - Endpoints (`language=en-US`): `GET search/tv?query=`, `GET tv/{tv_id}?append_to_response=credits,videos,watch/providers,recommendations,reviews`, `GET trending/tv/week`, `GET tv/popular`, `GET tv/airing_today`, `GET tv/on_the_air`.
   - Images: Posters `w500` (and `w185` thumbnails), Backdrops `w780`, Provider logos `w154`, Review avatars `w185` (or raw `http` URL if prefixed).
   - Built-in 26-entry `TMDB_GENRE_MAP` maps `genre_ids` on summary DTOs to genre names.
2. **Update & Stats APIs (`AboutScreen.kt`):**
   - `GET https://api.github.com/repos/tshivaneshk/Moglog-Releases/releases/latest` (latest release check)
   - `GET https://moglog-instructions.vercel.app/api/badge?format=json` (live download count) with fallback to `GET https://api.github.com/repos/tshivaneshk/Moglog-Releases/releases`.

---

## 4. Security Architecture

| Layer | Kotlin Implementation | Compatibility / Parity Notes |
|-------|-----------------------|------------------------------|
| **Backup & Cloud E2E Encryption** (`BackupCryptoEnvelope.kt`) | **Format:** `MOGLOG_ENC_V1`, `schemaVersion = 1`<br>**KDF:** `PBKDF2WithHmacSHA256`, `600,000` iterations (decrypt clamps `10,000..2,000,000`), 16-byte random salt, 256-bit key<br>**Cipher:** `AES/GCM/NoPadding`, 12-byte random IV, 128-bit auth tag (appended to ciphertext in JCE output)<br>**AAD:** UTF-8 bytes of `"moglog-backup:v<schemaVersion>:uid=<uid>"` (`uid = "local"` for `.moglog` files, Firebase `uid` for cloud)<br>**Encoding:** Standard Base64 (`java.util.Base64`) for `salt`, `iv`, `ciphertext`; Gson JSON serialization of `BackupEnvelopePayload` (`format`, `schemaVersion`, `kdf`, `kdfIterations`, `salt`, `iv`, `ciphertext`, `uid`, `createdAt`). | **MUST BE 100% BYTE-COMPATIBLE** in Flutter so `.moglog` files and E2E Firestore backups interoperate seamlessly between Kotlin and Flutter apps. Note: JCE `AES/GCM/NoPadding` outputs `ciphertext || 16-byte tag` concatenated in `ciphertext`. |
| **Local DB Encryption** | `sqlcipher-android` 4.6.1 encrypting `drama_db` with a 32-byte CSPRNG passphrase. | Flutter uses its own isolated app sandbox (`com.skech.moglog.flutter`), encrypted with `sqlcipher_flutter_libs` + `drift` using a 32-byte CSPRNG passphrase stored in `flutter_secure_storage`. |
| **Secret Storage** | Google Tink `AES256_GCM` wrapped in Android Keystore (`android-keystore://moglog_tink_master_key`) + software recovery keyset. Blocks compromised legacy TMDB key. | `flutter_secure_storage` (Android Keystore-backed) + validation blocking the same compromised legacy key. |
| **App Lock & Privacy Shield** | `BiometricPrompt` (`STRONG | WEAK | DEVICE_CREDENTIAL`), configurable timeout (0s / 60s / 300s), `FLAG_SECURE` when `hideInRecents || appLockEnabled`, background blur/cover overlay. | `local_auth` + small Android `MethodChannel` (or `screen_protector` / native `FLAG_SECURE`) + `WidgetsBindingObserver` lifecycle shield. |
| **Network Security** | `usesCleartextTraffic="false"`, `network_security_config.xml` enforcing HTTPS, trusted update host allowlist (`github.com`, `*.githubusercontent.com`, `moglog-instructions.vercel.app`). | Replicate `network_security_config.xml` in Flutter Android manifest + same host allowlist in Dart. |
| **Backup Exclusion** | `android:allowBackup="false"`, `backup_rules.xml`, `data_extraction_rules.xml`. | Replicate in Flutter `AndroidManifest.xml`. |
| **ProGuard / R8 Rules** | Keeps Gson/DTO/domain/envelope models, Room, SQLCipher JNI, Tink, Kotlinx Serialization, Credential Manager, Firebase Auth/AppCheck; strips `android.util.Log` in release builds. | Flutter AOT compiles Dart (no Gson reflection); keep rules only needed for Android plugins (SQLCipher, Firebase, Play Integrity, Credential Manager). |
| **CSV Formula Injection Defense** | `escapeCsvField` prefixes leading `=`, `+`, `-`, `@` with `'`. | Must preserve in Flutter CSV exporter. |

---

## 5. Business Logic Summary

1. **Library Filtering & Sorting (`LibraryScreen.kt`):**
   - Active items only (`!isDeleted`).
   - Status filter (`All` / `Watching` / `Planned` / `Done`).
   - Shelf filter: `null` (All Shelves), `"__TOP_FOUR__"` (ordered by `topFourFavoriteIds`), or case-insensitive tag match against `drama.tagList`.
   - `onlyPartiallyDone` toggle (`drama.isPartiallyDone`).
   - Search query: case-insensitive substring match across `title`, `notes`, `tags`.
   - Minimum rating: effective rating (`myRating > 0 ? myRating : rating`) `>= minRating`.
   - Genres: case-insensitive match of any genre in `drama.genreList` against `selectedGenres`.
   - 7 Sort options: `Recently Added` (`addedAt` desc), `Recently Updated` (`updatedAt` desc), `Recently Completed` (`completedAt` desc), `TMDB Rating` (`rating` desc), `My Rating` (effective rating desc), `Title (A–Z)` (lowercase asc), `Release Year` (`releaseYear` desc).
2. **Episode & Season Progress (`DetailScreen.kt`, `ProgressStepperCard.kt`, `LibraryScreen.kt`):**
   - `resolveSeasonBreakdown`: Uses TMDB seasons (`seasonNumber >= 1 && episodeCount > 0`), or synthesizes even split across `totalSeasons` (max 30) when offline.
   - Multi-season stepper scopes display & progress bar to `currentSeason` via cumulative `seasonOffset`.
   - Auto-promote `Planned → Watching` on first episode watched (`0 → 1`).
   - Completing a non-final season auto-advances `currentSeason` to next season while keeping status `"Watching"`.
   - Completing the final episode marks status `"Done"`, sets `completedAt`, plays celebration chime + haptic + confetti.
   - Quick `+1` from Library / Continue Watching caps at `totalEpisodes`, promotes `Planned → Watching` or completes to `"Done"` with celebration + Undo toast.
3. **Binge & Catch-Up Calculator (`DetailScreen.kt`):** Uses `episodeRuntime` (fallback 45 min), computes total/remaining hours & minutes, and `ceil(remainingEpisodes / pace)` days for `1, 2, 3, 5 ep/day`.
4. **Statistics & 13 Prestige Tiers (`StatsScreen.kt`):**
   - Episodes total counts `totalEpisodes` if `status == "Done" && episodesWatched == 0 && totalEpisodes > 0`.
   - Estimated hours = `(totalEpisodesWatched * 45) / 60`.
   - 12-month activity buckets using `completedAt > 0 ? completedAt : (updatedAt > 0 ? updatedAt : addedAt)`.
   - Monthly streak counts consecutive non-zero months working backwards from current month.
   - 13 Prestige Tiers (`TIER I` 0–10h through `TIER XIII` 3,500h+) evaluated on `effectiveHours = max(hoursWatched, doneCount * 10)`, dynamically themed per tier color & top genre, rendered both in UI and to a 1080×1350 PNG Wrapped Card.
5. **Watch Circle & Taste Blend (`WatchCircleModels.kt`, `WatchCircleRepository.kt`):**
   - Invite code: 6 chars from `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`; legacy deterministic SHA-256 of `"moglog-circle-v1:$uid"`, new/rotated via CSPRNG. Clipboard parser extracts `CODE: XXXXXX`, `MOG-XXXXXX`, or standalone 6-char alphanumeric token.
   - `TasteBlendCalculator.computeBlend`: Show Overlap (0–45 pts) + Genre Affinity (0–35 pts) + Rating Harmony (0–20 pts, neutral 14 pts if no shared ratings); clamped `[42..99]` if shared shows, `[28..78]` if shared genres, `[18..60]` otherwise; 5 badges (`Soulmate Watchers` ≥88, `Binge Twins` ≥75, `Vibe Match` ≥60, `Genre Explorers` ≥40, `Opposites Attract` <40).
   - `buildCoWatchPairs`: Matches shows friends are `currentlyWatching` against user's active library, sorted with user's `Watching` shows first.
6. **Import / Export (`DramaViewModel.kt`):**
   - Export: Encrypted `.moglog` (`BackupCryptoEnvelope`, `uid = "local"`) OR CSV (`title,tmdb_id,status,episodes_watched,total_episodes,season,rating,genres,tags`).
   - Import: Max 10 MB; auto-detects `.moglog` encrypted envelope vs CSV (flexible header aliases for Moglog, TV Time, Trakt; scales 5-star ratings to 10-point scale; up to 35 TMDB lookups to enrich metadata).
7. **Streaming Provider Deep Links (`WatchProvidersSection.kt`):**
   - Region resolution: Device country → `"US"` → first available region (shows `"Not in XX · Showing YY"` fallback badge).
   - Curated 13 platforms (`Netflix`, `Prime Video`, `Disney+ Hotstar`, `Disney+`, `Max`, `Hulu`, `Apple TV+`, `Crunchyroll`, `Rakuten Viki`, `iQIYI`, `WeTV`, `YouTube`, `Plex`) with installed-app prioritization, Netflix `nflx://` deep link, HTTPS search URLs, and TMDB/JustWatch fallback.

---

## 6. Permissions, Manifest & System Features

- **Permissions:** `INTERNET`, `POST_NOTIFICATIONS` (runtime requested on Android 13+ when enabling Episode Reminders), `VIBRATE`.
- **`<queries>`:** Explicit visibility for the 13 curated streaming app packages + `ACTION_VIEW` `https` browser intents (no `QUERY_ALL_PACKAGES`).
- **Activity Config:** `edgeToEdge`, `resizeableActivity="true"`, `adjustResize`, high refresh rate display negotiation (60–120Hz cap in `MainActivity.enableHighRefreshRateDisplay`), `FileProvider` scoped strictly to `cache/shared/`.
- **Removed Receivers:** Strips `WorkManager` `DiagnosticsReceiver` and `ProfileInstallReceiver`.

---

## 7. Design System, Theming, Assets & Localization

- **Color Tokens (`ui/designsystem/Tokens.kt`):**
  - **Dark (default):** `background #000000`, `secondaryBackground #1C1C1E`, `tertiaryBackground #2C2C2E`, `elevatedSurface #242426`, `frostedBarSurface #CC161618`, `separator #38383A`, `label #FFFFFF`, `secondaryLabel #99EBEBF5`, `tertiaryLabel #4DEBEBF5`, `accent #30D158`, `accentSubtle #2630D158`, `onAccent #000000`, `statusWatching #FF9F0A`, `statusPlanned #0A84FF`, `statusDone #30D158`, `destructive #FF453A`, `warning #FFD60A`, `starGold #FFD60A`.
  - **Light:** `background #F2F2F7`, `secondaryBackground #FFFFFF`, `tertiaryBackground #E5E5EA`, `elevatedSurface #FFFFFF`, `frostedBarSurface #CCF9F9FB`, `separator #C6C6C8`, `label #000000`, `secondaryLabel #993C3C43`, `tertiaryLabel #4D3C3C43`, `accent #34C759`, `accentSubtle #2234C759`, `onAccent #FFFFFF`, `statusWatching #FF9500`, `statusPlanned #007AFF`, `statusDone #34C759`, `destructive #FF3B30`, `warning #FFCC00`, `starGold #FFB800`.
- **Typography (`ui/designsystem/Typography.kt`):** Bundled `inter_variable.ttf` (OFL Inter variable font) on iOS type scale: `largeTitle` 34/41 Bold, `title1` 28/34 Bold, `title2` 22/28 Bold, `title3` 20/25 SemiBold, `headline` 17/22 SemiBold, `body` 17/22 Regular, `callout` 16/21 Regular, `subhead` 15/20 Regular, `footnote` 13/18 Regular, `caption` 12/16 Medium, `caption2` 11/14 Medium.
- **Shapes (`ui/designsystem/Shapes.kt`):** `SmoothRoundedCornerShape` (squircle cubic-bezier corners: `Control = 10`, `Card/Poster = 14`, `Sheet = 20`, `Pill = 50%`).
- **Icons (`ui/designsystem/Icons.kt`):** 36 custom 24dp Lucide-inspired rounded-outline vector icons (`Library`, `Discover`, `Stats`, `Settings`, `Search`, `Plus`, `Minus`, `Check`, `Close`, `ChevronLeft`, `ChevronRight`, `MoreHorizontal`, `StarFilled`, `StarOutline`, `Filter`, `Grid`, `ListRows`, `Trash`, `Share`, `Play`, `ExternalLink`, `Lock`, `Shield`, `Cloud`, `Key`, `Note`, `Refresh`, `Bell`, `Person`, `SunMoon`, `Download`, `Upload`, `Users`, `Sparkles`, `Copy`, `Zap`, `EyeOff`, `Eye`, `Camera`, `Photo`, `Calendar`, `Clock`, `Bookmark`, `BookmarkFilled`, `Award`, `TrendingUp`).
- **Motion & Haptics:** Spring physics (`dampingRatio 0.86`, `pressScale 0.97`, alpha `0.86` 90ms), reduce-motion check (`ANIMATOR_DURATION_SCALE == 0`), custom tactile vibration pulses (`tickMinus`, `clickPlus`, `selectionChanged`, `longPress`, `warning`).
- **Assets to Copy:** `res/font/inter_variable.ttf`, `res/drawable/app_logo2.png`, `res/drawable/app_logo.png`, `res/drawable/ic_stat_moglog.xml`, launcher icons (`ic_launcher*`).
- **Localization:** Single English locale (`res/values/strings.xml`, 185 lines, plus inline English UI copy across screens). Will be structured cleanly for Flutter localization (`l10n` / constants).

---

## 8. Third-Party Libraries: Kotlin-to-Flutter Mapping Table

| Category | Kotlin Library / API | Flutter / Dart Equivalent | Notes |
|----------|---------------------|---------------------------|-------|
| UI Framework | Jetpack Compose + Material 3 | Flutter Material 3 + Cupertino primitives + custom `MoglogDesignSystem` | Centralized `ThemeExtension<MoglogColors>` & `MoglogTypography` |
| State Management & DI | Hilt + ViewModel + `StateFlow` | `flutter_riverpod` (`Notifier` / `AsyncNotifier` / `StreamProvider`) | Compile-safe DI, reactive streams, easy testing |
| Navigation | Navigation Compose (Kotlinx Serialization routes) | `go_router` (`StatefulShellRoute.indexedStack` + push routes) | Preserves 4-tab state + custom iOS slide/parallax transitions |
| Local Encrypted DB | Room 2.6.1 + `sqlcipher-android` 4.6.1 | `drift` + `sqlcipher_flutter_libs` + `sqlite3` | Full SQLite schema parity, type-safe reactive streams, 256-bit SQLCipher |
| Preferences | Jetpack DataStore Preferences | `shared_preferences` (or `SharedPreferencesAsync`) | 1:1 key/default parity with `AppSettings` |
| Hardware Secure Storage | Google Tink AEAD + Android Keystore | `flutter_secure_storage` | Android Keystore-backed AES-GCM storage for TMDB key, DB key, backup passphrase |
| E2E Backup Crypto | JCE `PBKDF2WithHmacSHA256` + `AES/GCM/NoPadding` | `cryptography` (or `pointycastle` / Dart isolate) | **Byte-compatible `MOGLOG_ENC_V1`**, verified via cross-platform test vectors |
| Networking | Retrofit 2 + OkHttp + Gson | `dio` | Custom `TmdbAuthInterceptor` + timeouts + logging in debug |
| JSON Serialization | Gson / Kotlinx Serialization | `dart:convert` + explicit `fromJson`/`toJson` (matching exact Gson field names) | Zero field drift with Firestore & `.moglog` JSON |
| Image Loading & Caching | Coil Compose (150MB disk + 25% RAM) | `cached_network_image` + `flutter_cache_manager` | Custom cache manager with 150MB limit & smooth zero-flash placeholders |
| Dynamic Poster Tint | `androidx.palette:palette-ktx` | `palette_generator` (or pure-Dart dominant/vibrant color extractor) | Extracts vibrant/dominant swatch from poster image |
| Firebase Core / Auth / Firestore / App Check | `firebase-auth`, `firebase-firestore`, `firebase-appcheck-*` | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_app_check` | Connects to same Firebase project with distinct Android app ID |
| Google Sign-In | AndroidX Credential Manager + `googleid` | `google_sign_in` | Authenticates with Firebase `GoogleAuthProvider` |
| Biometric / PIN Lock | `androidx.biometric:biometric` | `local_auth` | Supports Face, Fingerprint, and Device Credential fallback |
| Background Workers | AndroidX WorkManager | `workmanager` | Daily Recycle Bin purge + 12h Episode Reminder check |
| Local Notifications | `NotificationCompat` (`BigPictureStyle` / `BigTextStyle`) | `flutter_local_notifications` | Same 2 channels (`moglog_episode_reminders`, `watch_circle_notifications`), poster big-picture, tap payload routing |
| Connectivity | `ConnectivityManager` | `connectivity_plus` | Offline checks for sync, restore, Watch Circle |
| File Export / Import (SAF) | `ActivityResultContracts.CreateDocument` / `OpenDocument` | `file_picker` (saveFile / pickFiles) | `.moglog` & `.csv` read/write |
| Sharing & External URLs | `Intent.ACTION_SEND`, `ACTION_VIEW`, `FileProvider` | `share_plus`, `url_launcher` | Text + poster image share, Wrapped card PNG share, trailers & streaming links |
| Save Image to Gallery | Android `MediaStore` | `gal` (or Android `MethodChannel` MediaStore helper) | Saves 1080×1350 Wrapped PNG to `Pictures/Moglog` |
| Camera / Gallery Picker | `TakePicture` / `GetContent` | `image_picker` + custom Flutter circular cropper dialog | Matches WhatsApp-style pan/zoom circular cropper (512×512 JPEG Base64) |
| Custom Icons | Custom Compose `ImageVector` (`MoglogIcons`) | `lucide_icons_flutter` (or exact SVG paths via `flutter_svg` / custom `CustomPainter`) | Exact 36 rounded-outline Lucide icons |
| Haptics & Vibration | `HapticFeedbackConstants` + `Vibrator` | `vibration` + Flutter `HapticFeedback` | Custom pulse durations + victory waveform `[0,45,55,45,55,110]` |
| Permissions | `ActivityResultContracts.RequestPermission` | `permission_handler` | Runtime `POST_NOTIFICATIONS` on Android 13+ |
| App Version / Package Info | `BuildConfig.VERSION_NAME` | `package_info_plus` | Version display & update check comparison |

---

## 9. Android-Only / Platform-Specific Features & Proposed Solutions

| # | Android-Specific Feature in Kotlin App | Flutter Solution |
|---|----------------------------------------|------------------|
| 1 | **`WindowManager.LayoutParams.FLAG_SECURE`** (Hide in App Switcher / block screenshots dynamically toggled by `hideInRecents \|\| appLockEnabled`) | Lightweight Kotlin `MethodChannel` (`com.skech.moglog.flutter/platform`) in Flutter's `MainActivity.kt` calling `window.setFlags`/`clearFlags(FLAG_SECURE)` — zero third-party dependency risk, exact parity. |
| 2 | **High Refresh Rate Negotiation (60–120Hz cap)** (`MainActivity.enableHighRefreshRateDisplay`) | Implement directly in Flutter's Android `MainActivity.kt` (`onCreate` / `onResume`) using the exact same `Display.Mode` selection logic. |
| 3 | **Installed Streaming App Detection & Native `nflx://` Deep-Link (`PackageManager.getLaunchIntentForPackage` + `<queries>`)** | Add the exact same 13 `<queries><package>` entries to Flutter's `AndroidManifest.xml`, and expose `isPackageInstalled(packageName)` + `launchPackageDeepLink(packageName, uri)` over the `com.skech.moglog.flutter/platform` `MethodChannel` (graceful no-op returning `false` on iOS/other platforms). |
| 4 | **Zero-Asset Synthesized 3-Tone Chime (`CelebrationAudio` via Android `AudioTrack` PCM)** | Generate the identical 16-bit 44.1kHz mono WAV buffer (C6→E6→G6 harmonic arpeggio) in pure Dart bytes and play via `audioplayers` (`BytesSource`), OR invoke Android `AudioTrack` via the platform channel. Pure-Dart WAV + `audioplayers` is cross-platform (Android + iOS) with zero audio asset files! |
| 5 | **System Reduce-Motion Setting (`Settings.Global.ANIMATOR_DURATION_SCALE`)** | Flutter natively exposes `MediaQuery.disableAnimationsOf(context)` which automatically reads Android's `ANIMATOR_DURATION_SCALE` and iOS's Reduce Motion! |
| 6 | **1080×1350 Wrapped Card Offscreen Rendering + Save to `Pictures/Moglog`** | Render offscreen in pure Dart using `dart:ui` `PictureRecorder` + `Canvas` → `toImage(1080, 1350)` → PNG bytes, then save to Gallery via `gal` (or MediaStore method on the platform channel) and share via `share_plus`. |
| 7 | **WorkManager Background Execution with SQLCipher + TMDB + Notifications** | Use `workmanager` package with a top-level `@pragma('vm:entry-point')` `callbackDispatcher` that opens the encrypted Drift DB using the key from `flutter_secure_storage`, checks TMDB, and posts `flutter_local_notifications` with big-picture poster download. |
| 8 | **Android 12+ Splash Screen (`#05050A`)** | Configure native `styles.xml` / `launch_background.xml` with `#05050A` background matching `Theme.App.Starting`, handing off seamlessly to Flutter's `MoglogStartupSplashScreen` overlay. |

---

## 10. Audit Completeness & Verification Notes

- Verified **zero modifications** to `C:\Users\tshiv\AndroidStudioProjects\Moglog`.
- Verified **every Kotlin source file (65 files)**, Gradle build script, `AndroidManifest.xml`, `proguard-rules.pro`, `firestore.rules`, XML configs, and unit tests.
- Noted dead/legacy code in Kotlin repo so we don't blindly port unused artifacts while preserving all data compatibility:
  - `WatchViewModel` & `shortcuts` table exist in DB/DI, while `WatchProvidersAndShortcutSection` currently ignores the `shortcut` parameter in favor of regional JustWatch/TMDB providers. We will preserve the `shortcuts` table in Drift for full schema completeness.
  - `ShowCompletionCelebrationDialog` is defined in `ShowCompletionCelebration.kt` but unused (celebration uses `CelebrationBlastOverlay` + audio + haptics + toast).
  - `SettingsScreen.kt` contains superseded sheet definitions now hosted in `AccountSettingsScreen` and `AdvancedSettingsScreen`.
  - No Jetpack Glance widget exists in v3.0.73.
