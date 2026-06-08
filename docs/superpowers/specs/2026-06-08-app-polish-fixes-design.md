# Design: App polish fixes — name, leaderboard wiring, Facebook share, Main Menu button

**Date:** 2026-06-08
**Status:** Approved (design); pending spec review
**Scope:** Android-first. Four independent, mostly-small changes.

## Summary

Four user-reported issues:

1. The launcher label reads `merge_loop`; it should read **Merge Loop**.
2. The global and Friends leaderboards "never appear and have no button." They are in fact fully built but disabled because the app ships without Supabase credentials.
3. The Share button only copies text to the clipboard; the user wants it to screenshot the result and open the Facebook app with the image attached.
4. After a round ends there is no **Main Menu** button on the result screen.

Each section below is self-contained and can be implemented/landed independently.

---

## 1. Launcher display name → "Merge Loop"

### Current state
- `android/app/src/main/AndroidManifest.xml:9` — `android:label="merge_loop"`.
- `ios/Runner/Info.plist` — `CFBundleDisplayName` is already `Merge Loop` (line 35); `CFBundleName` is `merge_loop` (line 43). On iOS the home-screen label uses `CFBundleDisplayName`, so iOS is already correct.
- The in-app title and `MaterialApp(title:)` already read "Merge Loop".

### Change
- Android: `android:label="merge_loop"` → `android:label="Merge Loop"`.
- iOS (consistency, optional but cheap): `CFBundleName` `merge_loop` → `Merge Loop`. Not required for the home-screen label since `CFBundleDisplayName` already governs it; included only for internal consistency.

### Verification
- Build the Android app; confirm the launcher label reads "Merge Loop".

---

## 2. Leaderboards — connect the existing (but disabled) online layer

### Root cause
The global board (`LeaderboardScreen`) and Friends board are fully implemented and already wired with entry points:
- Per-tier leaderboard icon — `tier_select_screen.dart:457` (`if (widget.leaderboard != null)`).
- Friends icon in the header — `tier_select_screen.dart:345` (`if (widget.friends != null)`).

Both `widget.leaderboard` and `widget.friends` are non-null **only** when `initSupabase()` succeeds, which requires `SUPABASE_URL` + `SUPABASE_ANON_KEY` provided at build time via `--dart-define` (`supabase_client.dart:9-15`). The shipped APK was built without these, so the whole online layer silently disabled and every leaderboard entry point disappeared.

There is no committed mechanism to inject the keys, which is why every build shipped offline.

### Backend status
- Migrations exist in `supabase/migrations/0001`–`0005` and the Supabase CLI is a local dev dependency (`node_modules/@supabase`).
- The user is unsure whether these are deployed to the live project. They must be confirmed pushed before the boards return data.

### Changes

**2a. Deploy / verify the backend (user-assisted; needs project credentials).**
- Document and run:
  - `npx supabase link --project-ref <project-ref>`
  - `npx supabase db push`
- Verification query (run via `npx supabase db remote ...` or the SQL editor) to confirm the leaderboard RPCs exist, e.g. checking `pg_proc` for the daily-leaderboard and `ensure_friend_code` / `redeem_code` functions referenced by `LeaderboardService` and `FriendsService`.
- This step depends on the user's Supabase project ref + access; it is partly a user action, not pure code.

**2b. Wire keys into builds via `--dart-define-from-file`.**
- Add `env/supabase.json` (git-ignored) consumed at build time:
  ```json
  { "SUPABASE_URL": "https://<ref>.supabase.co", "SUPABASE_ANON_KEY": "<anon-key>" }
  ```
- Commit `env/supabase.example.json` as a template.
- Add `env/supabase.json` to `.gitignore`.
- Build command becomes:
  `flutter build apk --release --dart-define-from-file=env/supabase.json`
  (and likewise for `flutter run`).
- Add a short "Building with online features" section to the project docs/README documenting this.

**2c. Discoverability — a prominent Leaderboard button on the main menu.**
- The existing entry points are small icons that are easy to miss and vanish entirely when offline — which is why the user perceived "no button on any screen."
- Add a clearly-labeled **"Leaderboard"** button to the main menu (`TierSelectScreen`). It is always visible.
  - Online (`widget.leaderboard != null`): opens `LeaderboardScreen` (defaulting to the first tier; the screen already has tier tabs + Global/Friends toggle).
  - Offline (`widget.leaderboard == null`): the button remains visible but a tap shows a snackbar — "Leaderboards need an internet connection." — so there is always a discoverable button on screen.
- The per-tier leaderboard icons stay as-is (a quick path to a specific tier's board).

### Design notes
- The Global vs Friends ("local") distinction is already handled inside `LeaderboardScreen` via the `SegmentedButton` scope toggle (`leaderboard_screen.dart:120`), shown only when a `friendsService` is present. No new screen is needed — "local leaderboard" = the existing Friends scope.
- No changes to `LeaderboardScreen` / `LeaderboardService` / `FriendsService` logic are required; this is wiring + discoverability only.

### Verification
- Build with `--dart-define-from-file=env/supabase.json`; launch; confirm the main-menu Leaderboard button opens a populated board and the Global/Friends toggle works.
- Build without the file; confirm the button is still visible and tapping shows the offline snackbar.

---

## 3. Share button → screenshot into the Facebook composer (Android)

### Current state
`ScoreShareScreen._share` (`score_share_screen.dart:113`) copies emoji text to the clipboard in production because `shareText` is never injected by `GameScreen._buildResult` (`game_screen.dart:109`). The `_nativeShare` helper exists but is only used by the invite CTA.

### Constraint (why this is image-based, not text/link-based)
Facebook's platform policy bans pre-filled share **text/captions**. Facebook will only accept (a) a link (rendered from Open Graph tags) or (b) an image the user captions themselves. The user wants the score visible with minimal setup and Android-only, so the design is: **render the result card to a PNG and hand that image to the Facebook app**, which opens its composer with the image attached and an empty caption.

This deliberately avoids the Facebook SDK, an FB App ID/client token, OG hosting, and app review — none are needed for an `ACTION_SEND` image intent.

### Changes

**3a. Capture the result card to PNG.**
- Wrap the result card content in `ScoreShareScreen` in a `RepaintBoundary` with a `GlobalKey`.
- On Share, call `boundary.toImage(pixelRatio: ...)` → `toByteData(format: png)` → `Uint8List`.

**3b. Android intent that targets Facebook.**
- Add a `MethodChannel` (e.g. `merge_loop/facebook_share`) handled in `MainActivity.kt` (currently an empty `FlutterActivity`).
- The Kotlin handler:
  1. Writes the PNG bytes to the app cache dir.
  2. Obtains a `content://` URI via a declared `FileProvider`.
  3. Builds `Intent(ACTION_SEND)` with `type = "image/png"`, `EXTRA_STREAM = uri`, `addFlags(FLAG_GRANT_READ_URI_PERMISSION)`, and `setPackage("com.facebook.katana")`.
  4. `try { startActivity(...) ; result.success(true) }` / `catch (ActivityNotFoundException) { result.success(false) }`.
- Manifest additions:
  - A `FileProvider` `<provider>` with authority `${applicationId}.fileprovider` + `res/xml/provider_paths.xml` exposing the cache dir.
  - `<package android:name="com.facebook.katana"/>` inside the existing `<queries>` block (`AndroidManifest.xml:65`) for Android 11+ package visibility.

**3c. Dart-side flow + fallback.**
- New seam, e.g. `FacebookImageShare` with `Future<bool> shareImage(Uint8List png)` calling the channel (returns whether FB handled it). Tests inject a fake.
- `_share` becomes: capture PNG → `shareImage(png)`; if it returns `false` (Facebook not installed / `ActivityNotFoundException`), fall back to the OS share sheet with the same PNG via `share_plus` `Share.shareXFiles([XFile(tempPngPath)])`.
- The existing `shareText` seam is retained for tests and keeps the headless clipboard path as a last resort.

### Result
Tapping Share opens the Facebook app's composer with the score-card screenshot already attached and an empty caption (the user types their own words). If Facebook isn't installed, the OS share sheet appears with the same image.

### Verification
- On a device with Facebook installed: tap Share → Facebook composer opens with the image attached.
- On a device without Facebook: tap Share → OS share sheet with the image.
- Widget test: with a fake `FacebookImageShare` returning `false`, Share invokes the `share_plus` fallback seam.

---

## 4. "Main Menu" button on the result screen

### Current state
After a round, `GameScreen` renders `ScoreShareScreen` inside the same pushed route (`game_screen.dart:109`). There is no explicit way back to the menu other than the system back gesture.

### Change
- Add an `onMainMenu` callback to `ScoreShareScreen` (keeps it testable; no direct `Navigator` dependency in the widget).
- Render a **"Main Menu"** button directly below the **Share** button in the result screen's button column (`score_share_screen.dart:85-89`). Order: `Watch ad` (conditional) → `Share` → `Main Menu` → `Invite a friend` (conditional).
- `GameScreen._buildResult` passes `onMainMenu: () => Navigator.of(context).pop()`, which returns to `TierSelectScreen`. On return, the tier-select screen already refreshes its "done today" badges and reschedules notifications via the existing `.then(...)` on the game route push (`tier_select_screen.dart:220`).

### Verification
- Finish/end a round → "Main Menu" button appears below "Share" → tapping it returns to the tier-select main menu with badges refreshed.
- Widget test: tapping the Main Menu button invokes the `onMainMenu` callback.

---

## Out of scope / explicitly not doing
- Facebook SDK integration, FB App ID/client token, Open Graph hosting at `mergeloop.app`, app review — avoided by the image-intent approach.
- iOS Facebook share (Android-only release; iOS would require the FB SDK for an equivalent "open composer with image" flow).
- Any change to leaderboard data logic, RPCs, or schema beyond confirming deployment.
- Geographic/"nearby players" leaderboard.

## Risks / open items
- **Backend deployment depends on user credentials.** If migrations `0001`–`0005` are not actually pushed, the boards will show the empty/error state even after wiring keys. Deployment + verification is a prerequisite, gated on the user's Supabase project ref + access.
- **Facebook intent behavior varies by FB app version.** Some versions route `ACTION_SEND` to an internal share UI rather than the feed composer; the image always attaches, but the exact composer surface is FB's choice. The OS-share-sheet fallback covers the not-installed case.
- **Secrets handling.** `env/supabase.json` must be git-ignored; only `env/supabase.example.json` is committed. The anon key is a publishable key (safe in client builds) but is still kept out of source control per existing convention.
