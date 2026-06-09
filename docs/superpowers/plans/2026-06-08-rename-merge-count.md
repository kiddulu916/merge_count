# Merge Count Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the app from "Merge Loop" to "Merge Count" across every layer — display name, app identity, deep links, copy, internal Dart/Kotlin identifiers, and config.

**Architecture:** Mechanical rename executed as small, independently-committable tasks ordered for safety. The riskiest change (the Dart package name + 177 imports) goes first and is verified by the full test suite. String changes that an existing test asserts on are edited together with that test, so the suite stays green at every commit. Native-only changes (Android/iOS identity) are verified by `flutter analyze` + `flutter test` staying green plus a targeted grep, since the iOS/Android build toolchains are not available in this environment.

**Tech Stack:** Flutter (Dart), Kotlin (Android host), Xcode pbxproj (iOS), Gradle Kotlin DSL, Hive, Supabase config.

**TDD note:** This is a rename, not new behavior. The existing test suite is the regression guard. "Write a failing test" is replaced by "update the existing assertion (where one exists) and confirm the suite is red→green," and every task ends by running `flutter analyze` + `flutter test` and committing.

**Identifier decisions (locked — from the spec):**

| Concern | Old | New |
|---|---|---|
| Display name | `Merge Loop` | `Merge Count` |
| Android applicationId / namespace | `com.kiddulu.merge_loop` | `com.kiddulu.merge_count` |
| iOS bundle id | `com.mergeloop.mergeLoop` | `com.kiddulu.mergeCount` |
| Deep-link scheme | `mergeloop://` | `mergecount://` |
| Deep-link domain | `mergeloop.app` | `mergecount.app` |
| iOS URL-type id | `com.mergeloop.invite` | `com.mergecount.invite` |
| Dart package | `merge_loop` | `merge_count` |
| Root Dart classes | `MergeLoopApp` / `_MergeLoopAppState` | `MergeCountApp` / `_MergeCountAppState` |
| MethodChannel | `merge_loop/facebook_share` | `merge_count/facebook_share` |
| Hive box | `merge_loop` | `merge_count` |

**Environment:** Windows + PowerShell. Run all commands from the repo root `C:\Users\dat1k\Projects\merge_loop`. Bulk text replacements use `[System.IO.File]::ReadAllText/WriteAllText` (UTF-8, no BOM) to avoid PowerShell's default UTF-16/BOM output corrupting source files.

---

## Task 1: Rename the Dart package (pubspec name + 177 imports + root classes)

This MUST be one atomic task: renaming the `pubspec.yaml` package name without rewriting every `package:merge_loop/...` import (or vice-versa) leaves the project uncompilable.

**Files:**
- Modify: `pubspec.yaml:1`
- Modify: every `*.dart` under `lib/` and `test/` containing `package:merge_loop/` (177 occurrences across 32 files)
- Modify: `lib/main.dart` (classes `MergeLoopApp` / `_MergeLoopAppState`, lines 82/95/106/120/123)

- [ ] **Step 1: Rename the package in pubspec.yaml**

Edit `pubspec.yaml` line 1:

```yaml
name: merge_count
```

(was `name: merge_loop`)

- [ ] **Step 2: Rewrite all package imports across lib/ and test/**

Run from repo root:

```powershell
Get-ChildItem -Path lib,test -Recurse -Filter *.dart | ForEach-Object {
  $p = $_.FullName
  $c = [System.IO.File]::ReadAllText($p)
  $n = $c -replace 'package:merge_loop/', 'package:merge_count/'
  if ($n -ne $c) { [System.IO.File]::WriteAllText($p, $n) }
}
```

- [ ] **Step 3: Rename the root app classes in main.dart**

The string `MergeLoopApp` is a substring of `_MergeLoopAppState`, so a single scoped replace fixes all five occurrences (class decl, const ctor, `createState` return, state-class decl, and the `runApp(...)` call):

```powershell
$p = 'lib/main.dart'
$c = [System.IO.File]::ReadAllText($p)
$c = $c -replace 'MergeLoopApp', 'MergeCountApp'
[System.IO.File]::WriteAllText($p, $c)
```

- [ ] **Step 4: Verify there are no stale Dart references**

Run: `rg -n "package:merge_loop|MergeLoopApp" lib test`
Expected: **no matches**.

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` (an unchanged-from-baseline result; if the baseline already had lints, no *new* issues).

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (the rename is path-only; no assertions changed).

- [ ] **Step 7: Commit**

```powershell
git add pubspec.yaml lib test
git commit -m "refactor: rename Dart package merge_loop -> merge_count"
```

---

## Task 2: Display name + native copy strings (Android/iOS/in-app)

Changes only the human-readable name. No test asserts these strings (verified: the only `Merge Loop` test assertion is in `share_grid_builder_test`, handled in Task 4).

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (label line 9, comment line 2)
- Modify: `ios/Runner/Info.plist` (CFBundleDisplayName line 35, CFBundleName line 43, NSContactsUsageDescription line 12, comment line 7)
- Modify: `lib/main.dart:212` (MaterialApp title)
- Modify: `lib/presentation/screens/tier_select_screen.dart:333` (header text)

- [ ] **Step 1: Replace the "Merge Loop" phrase in the four files**

A case-sensitive phrase replace of `Merge Loop` → `Merge Count` converts the Android label, both iOS bundle strings, the iOS contacts-permission description, the two "find friends already on Merge Loop" comments, the in-app `MaterialApp.title`, and the tier-select header — without touching any identifier (which use `merge_loop`/`mergeloop`/`mergeLoop`, different casing):

```powershell
$files = @(
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
  'lib/main.dart',
  'lib/presentation/screens/tier_select_screen.dart'
)
foreach ($f in $files) {
  $c = [System.IO.File]::ReadAllText($f)
  $n = $c -replace 'Merge Loop', 'Merge Count'
  if ($n -ne $c) { [System.IO.File]::WriteAllText($f, $n) }
}
```

- [ ] **Step 2: Verify the display-name changes landed**

Run: `rg -n "Merge Count" android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/main.dart lib/presentation/screens/tier_select_screen.dart`
Expected: matches for `android:label="Merge Count"`, two `<string>Merge Count</string>`, the `Merge Count can find friends...` description, `title: 'Merge Count'`, and `Text('Merge Count'`.

- [ ] **Step 3: Analyze + test**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test`
Expected: all pass (no test asserts the display name).

- [ ] **Step 4: Commit**

```powershell
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/main.dart lib/presentation/screens/tier_select_screen.dart
git commit -m "feat(brand): display name Merge Loop -> Merge Count"
```

---

## Task 3: Deep-link scheme + domain (source + coupled tests)

Changes `mergeloop://` → `mergecount://`, `mergeloop.app` → `mergecount.app`, and the iOS URL-type id `com.mergeloop.invite` → `com.mergecount.invite`. Three test files assert on these strings, so they are edited in the same task to keep the suite green.

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (scheme line 41, host line 50, comments 36/43)
- Modify: `ios/Runner/Info.plist` (URL name line 20, scheme line 23, comments 13/28)
- Modify: `lib/infrastructure/friends_service.dart:80,84`
- Modify: `lib/infrastructure/deep_link_service.dart:8,9,37,38`
- Modify: `lib/main.dart:73` (comment)
- Test: `test/infrastructure/friends_service_test.dart:49,53`
- Test: `test/infrastructure/deep_link_service_test.dart:6,8,16,23,37,38`
- Test: `test/presentation/friends_screen_test.dart:171`

- [ ] **Step 1: Confirm the tests currently assert the OLD scheme (red baseline)**

Run: `rg -n "mergeloop" test`
Expected: matches in the three test files above. These are the assertions that must flip to `mergecount`.

- [ ] **Step 2: Replace `mergeloop` across the deep-link source AND test files**

The lowercase token `mergeloop` appears ONLY in deep-link contexts (scheme, `mergeloop.app`, `com.mergeloop.invite`) within these files, so a scoped token replace covers scheme + domain + URL-id in one pass. The iOS bundle id `com.mergeloop.mergeLoop` lives in `project.pbxproj`, which is deliberately NOT in this list (it is Task 8):

```powershell
$files = @(
  'android/app/src/main/AndroidManifest.xml',
  'ios/Runner/Info.plist',
  'lib/infrastructure/friends_service.dart',
  'lib/infrastructure/deep_link_service.dart',
  'lib/main.dart',
  'test/infrastructure/friends_service_test.dart',
  'test/infrastructure/deep_link_service_test.dart',
  'test/presentation/friends_screen_test.dart'
)
foreach ($f in $files) {
  $c = [System.IO.File]::ReadAllText($f)
  $n = $c -replace 'mergeloop', 'mergecount'
  if ($n -ne $c) { [System.IO.File]::WriteAllText($f, $n) }
}
```

- [ ] **Step 3: Verify the scheme/domain are fully flipped**

Run: `rg -n "mergeloop" android lib test`
Expected: **no matches** (these files are fully converted).
Run: `rg -n "mergeloop" ios`
Expected: matches ONLY in `ios/Runner.xcodeproj/project.pbxproj`, as the `com.mergeloop.` segment of the bundle id `com.mergeloop.mergeLoop` (lowercase `mergeloop` is a substring of it). That bundle id is handled in Task 8. `ios/Runner/Info.plist` must have **no** matches.

- [ ] **Step 4: Run the coupled tests, then the full suite**

Run: `flutter test test/infrastructure/deep_link_service_test.dart test/infrastructure/friends_service_test.dart test/presentation/friends_screen_test.dart`
Expected: all pass (assertions now expect `mergecount://` and `mergecount.app`).
Run: `flutter test`
Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/infrastructure/friends_service.dart lib/infrastructure/deep_link_service.dart lib/main.dart test/infrastructure/friends_service_test.dart test/infrastructure/deep_link_service_test.dart test/presentation/friends_screen_test.dart
git commit -m "feat(deeplink): mergeloop:// -> mergecount:// and mergecount.app"
```

---

## Task 4: Dart share/copy strings (+ coupled share-grid test)

Changes user-facing share text, share subjects, and friend-match status strings. `share_grid_builder_test.dart:27` asserts `'Merge Loop 2026-06-06'`, so it is edited in the same task.

**Files:**
- Modify: `lib/presentation/screens/score_share_screen.dart:174,182`
- Modify: `lib/presentation/screens/friends_screen.dart:107,109,135,136`
- Modify: `lib/domain/engine/share_grid_builder.dart:11`
- Modify: `lib/infrastructure/score_sharer.dart:48`
- Test: `test/domain/engine/share_grid_builder_test.dart:27`

- [ ] **Step 1: Replace the `Merge Loop` phrase across the copy + coupled test**

A case-sensitive `Merge Loop` → `Merge Count` phrase replace handles every variant in these files: `Add me on Merge Loop!`, subject `'Merge Loop'`, `'Merge Loop invite'`, `No contacts are on Merge Loop yet.`, `Found N contact(s) on Merge Loop.`, `'Merge Loop $date'`, and the test's `'Merge Loop 2026-06-06'`:

```powershell
$files = @(
  'lib/presentation/screens/score_share_screen.dart',
  'lib/presentation/screens/friends_screen.dart',
  'lib/domain/engine/share_grid_builder.dart',
  'lib/infrastructure/score_sharer.dart',
  'test/domain/engine/share_grid_builder_test.dart'
)
foreach ($f in $files) {
  $c = [System.IO.File]::ReadAllText($f)
  $n = $c -replace 'Merge Loop', 'Merge Count'
  if ($n -ne $c) { [System.IO.File]::WriteAllText($f, $n) }
}
```

- [ ] **Step 2: Run the coupled test, then the full suite**

Run: `flutter test test/domain/engine/share_grid_builder_test.dart`
Expected: pass (now expects `'Merge Count 2026-06-06'`).
Run: `flutter test`
Expected: all pass.

- [ ] **Step 3: Commit**

```powershell
git add lib/presentation/screens/score_share_screen.dart lib/presentation/screens/friends_screen.dart lib/domain/engine/share_grid_builder.dart lib/infrastructure/score_sharer.dart test/domain/engine/share_grid_builder_test.dart
git commit -m "feat(share): rebrand share/invite copy to Merge Count"
```

---

## Task 5: Platform channel rename (Dart + Kotlin together) + temp file name

The MethodChannel name is a string contract duplicated in Dart and Kotlin; changing only one side silently breaks Facebook sharing. Both change in this single task/commit. No test references the channel (verified), so the gate is analyze + test.

**Files:**
- Modify: `lib/infrastructure/score_sharer.dart:26` (channel name), `:46` (temp filename)
- Modify: `android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt:12` (channelName)

- [ ] **Step 1: Update the Dart channel name**

Edit `lib/infrastructure/score_sharer.dart` line 26:

```dart
  static const MethodChannel _channel =
      MethodChannel('merge_count/facebook_share');
```

(was `MethodChannel('merge_loop/facebook_share')`)

- [ ] **Step 2: Update the Dart temp filename**

Edit `lib/infrastructure/score_sharer.dart` line 46:

```dart
    final file = File('${dir.path}/merge_count_score.png');
```

(was `merge_loop_score.png`)

- [ ] **Step 3: Update the Kotlin channelName to match**

Edit `android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt` line 12:

```kotlin
    private val channelName = "merge_count/facebook_share"
```

(was `"merge_loop/facebook_share"`)

- [ ] **Step 4: Verify the two sides match exactly**

Run: `rg -n "facebook_share" lib android`
Expected: both occurrences read `merge_count/facebook_share` — identical strings.

- [ ] **Step 5: Analyze + test**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test`
Expected: all pass.

- [ ] **Step 6: Commit**

```powershell
git add lib/infrastructure/score_sharer.dart android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt
git commit -m "refactor(share): rename FB platform channel to merge_count"
```

---

## Task 6: Hive box name

Internal persistence key. Renaming it orphans any local dev data, which is acceptable (app unpublished). No test asserts the box name (verified).

**Files:**
- Modify: `lib/infrastructure/hive_storage_service.dart:16`

- [ ] **Step 1: Rename the box constant**

Edit `lib/infrastructure/hive_storage_service.dart` line 16:

```dart
  static const _boxName = 'merge_count';
```

(was `static const _boxName = 'merge_loop';`)

- [ ] **Step 2: Analyze + test**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test`
Expected: all pass (Hive tests use whatever `_boxName` resolves to, so the change is transparent).

- [ ] **Step 3: Commit**

```powershell
git add lib/infrastructure/hive_storage_service.dart
git commit -m "refactor(storage): rename Hive box merge_loop -> merge_count"
```

---

## Task 7: Android app identity + Kotlin package move

Changes `applicationId`/`namespace` and moves the Kotlin source into the matching package directory. The Android build toolchain is unavailable here, so verification is `flutter analyze` + `flutter test` (Dart unaffected) plus grep; a real Android build is part of the manual steps.

**Files:**
- Modify: `android/app/build.gradle.kts:19` (namespace), `:31` (applicationId)
- Move: `android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt` → `android/app/src/main/kotlin/com/kiddulu/merge_count/MainActivity.kt`
- Modify: `MainActivity.kt:1` (package declaration)

- [ ] **Step 1: Update namespace and applicationId**

Edit `android/app/build.gradle.kts` line 19:

```kotlin
    namespace = "com.kiddulu.merge_count"
```

Edit line 31:

```kotlin
        applicationId = "com.kiddulu.merge_count"
```

- [ ] **Step 2: Move the Kotlin source to the new package directory**

`git mv` creates the destination directory automatically:

```powershell
git mv android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt android/app/src/main/kotlin/com/kiddulu/merge_count/MainActivity.kt
Remove-Item android/app/src/main/kotlin/com/kiddulu/merge_loop -Force -ErrorAction SilentlyContinue
```

- [ ] **Step 3: Update the Kotlin package declaration**

Edit `android/app/src/main/kotlin/com/kiddulu/merge_count/MainActivity.kt` line 1:

```kotlin
package com.kiddulu.merge_count
```

(was `package com.kiddulu.merge_loop`)

- [ ] **Step 4: Verify no Android references to the old id/package remain**

Run: `rg -n "com.kiddulu.merge_loop|com/kiddulu/merge_loop" android`
Expected: **no matches**.
Run: `rg -n "com.kiddulu.merge_count" android`
Expected: namespace, applicationId, and the Kotlin `package` line.

- [ ] **Step 5: Analyze + test**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test`
Expected: all pass.

- [ ] **Step 6: Commit**

```powershell
git add android
git commit -m "feat(android): applicationId com.kiddulu.merge_count + move Kotlin package"
```

---

## Task 8: iOS bundle identifier

Changes the 6 `PRODUCT_BUNDLE_IDENTIFIER` entries (app + 3 test-target configs). iOS build toolchain is unavailable here, so verification is grep + the Dart suite staying green; the entitlement/domain work is in the manual steps.

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (6 occurrences)

- [ ] **Step 1: Replace the bundle identifier base**

`com.mergeloop.mergeLoop` → `com.kiddulu.mergeCount` also fixes the `.RunnerTests` variants (`com.mergeloop.mergeLoop.RunnerTests` → `com.kiddulu.mergeCount.RunnerTests`) in one pass:

```powershell
$p = 'ios/Runner.xcodeproj/project.pbxproj'
$c = [System.IO.File]::ReadAllText($p)
$n = $c -replace 'com\.mergeloop\.mergeLoop', 'com.kiddulu.mergeCount'
[System.IO.File]::WriteAllText($p, $n)
```

- [ ] **Step 2: Verify**

Run: `rg -n "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj`
Expected: three `= com.kiddulu.mergeCount;` and three `= com.kiddulu.mergeCount.RunnerTests;`.
Run: `rg -n "mergeLoop|mergeloop" ios`
Expected: **no matches**.

- [ ] **Step 3: Confirm the Dart suite is unaffected**

Run: `flutter test`
Expected: all pass.

- [ ] **Step 4: Commit**

```powershell
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(ios): bundle id com.kiddulu.mergeCount"
```

---

## Task 9: Config & docs

**Files:**
- Modify: `supabase/config.toml:5` (project_id)
- Modify: `.env.example:1` (comment)
- Rewrite: `README.md` (currently UTF-16; rewrite as UTF-8)
- Modify: `docs/BUILD.md:1` (title)

- [ ] **Step 1: Update the Supabase local project id**

Edit `supabase/config.toml` line 5:

```toml
project_id = "merge_count"
```

(was `project_id = "merge_loop"`)

- [ ] **Step 2: Update the .env.example header comment**

Edit `.env.example` line 1:

```
# Supabase credentials for merge_count (Competitive Daily Expansion).
```

(was `... for merge_loop ...`)

- [ ] **Step 3: Rewrite README.md as UTF-8**

The file is UTF-16-encoded and contains only the title. Overwrite it with UTF-8 content:

```powershell
Set-Content -Path README.md -Value "# Merge Count" -Encoding utf8 -NoNewline
```

- [ ] **Step 4: Update the BUILD.md title**

Edit `docs/BUILD.md` line 1:

```markdown
# Building Merge Count
```

(was `# Building Merge Loop`)

- [ ] **Step 5: Verify**

Run: `rg -n "merge_loop|Merge Loop" supabase/config.toml .env.example README.md docs/BUILD.md`
Expected: **no matches**.

- [ ] **Step 6: Commit**

```powershell
git add supabase/config.toml .env.example README.md docs/BUILD.md
git commit -m "docs(config): rebrand project id and docs to merge_count"
```

---

## Task 10: Final verification sweep

Confirms the rebrand is complete and the only surviving old-name references are the deliberately-preserved historical docs.

**Files:** none (verification gate only).

- [ ] **Step 1: Full residual grep (excluding preserved historical docs)**

Run:

```powershell
rg -n "merge_loop|mergeloop|mergeLoop|MergeLoop|Merge Loop" --glob "!docs/superpowers/**" --glob "!docs/ideation/**"
```

Expected: **no matches**. (Any hit outside the excluded docs is a missed spot — fix it in the relevant task's file and re-commit before proceeding.)

- [ ] **Step 2: Confirm the new name is present where expected**

Run: `rg -n "merge_count" pubspec.yaml android/app/build.gradle.kts`
Expected: `name: merge_count` in pubspec and `com.kiddulu.merge_count` (namespace + applicationId) in Gradle.

- [ ] **Step 3: Full analyze + test**

Run: `flutter analyze`
Expected: no new issues.
Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 4: Confirm a clean tree**

Run: `git status`
Expected: nothing to commit, working tree clean (all changes committed across Tasks 1–9).

---

## Post-implementation

The code rebrand is complete. The remaining real-world steps (new keystore, hosting `assetlinks.json` / `apple-app-site-association` for `mergecount.app`, Associated Domains entitlement, Supabase dashboard rename, optional repo-folder rename) are documented in `docs/superpowers/specs/2026-06-08-rename-merge-count-manual-steps.md` and are the owner's to perform.
