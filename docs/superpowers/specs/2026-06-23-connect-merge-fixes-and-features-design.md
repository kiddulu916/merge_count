# Connect Merge — Fixes, Weekly Prizes, Daily Challenge & Rename

**Date:** 2026-06-23
**Status:** Approved design — ready for implementation planning
**Author:** Design session (brainstorming)

---

## 1. Problem & goals

Four independent but related goals:

1. **Fix the share button** — silent failure due to a `MethodChannel` name mismatch between Dart and the Android native layer.
2. **Fix the leaderboard** — player name and score not appearing because the `players` row in Supabase is never written (display-name onboarding not completed, or Supabase env vars missing).
3. **Weekly top-3 prizes** — give players a tangible incentive to climb the weekly leaderboard (coins + permanent champion badge).
4. **Daily Challenge mode** — a new time-locked (noon UTC unlock) special-rule board that draws players back mid-day, with a top-10 coin payout.
5. **Rename** — replace all instances of `merge_loop` / `merge_count` with `connect_merge` in functional code identifiers.

---

## 2. Bug fixes

### 2.1 Share button

**Root cause:** `PlatformScoreSharer` in `lib/infrastructure/score_sharer.dart` registers `MethodChannel('merge_count/facebook_share')`. The Android `MainActivity.kt` still registers the channel under the old name `merge_loop/facebook_share`. The mismatch throws a `MissingPluginException` that is swallowed silently — the button does nothing.

**Fix:** Update `MainActivity.kt`'s `channelName` constant to match the Dart side. After Section 3's rename, both sides move together to `connect_merge/facebook_share`.

**Verification:** Build on a real Android device; share button either opens the Facebook composer (if installed) or falls through to the OS share sheet via `SharePlus`.

### 2.2 Leaderboard name/score

**Root cause:** The `submit-score` Edge Function identifies the player by their Supabase auth token and reads `display_name` from the `players` table. If either of the following is true, the row is absent and the leaderboard shows a blank name:

- The `DisplayNameScreen` flow was never completed (the `players` row was never upserted).
- The `--dart-define` Supabase env vars are missing from the run/build command, so `initSupabase()` returns `false`, anonymous sign-in never fires, and `onSubmitRun` is never wired.

**Fix:**
1. Verify `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...` are present in the build command.
2. On cold start, if `auth.hasDisplayName()` returns `false`, always route to `DisplayNameScreen` before `TierSelectScreen` (already wired in `main.dart` via `needsDisplayName` — confirm the flag is being set correctly).

---

## 3. Rename: `merge_loop` / `merge_count` → `connect_merge`

The Dart **package name** (`name:` in `pubspec.yaml`) is deliberately left as `merge_count` — changing it would require updating all 177 `package:merge_count/...` imports with no user-visible benefit. All functional and user-visible identifiers change:

| File | Old | New |
|---|---|---|
| `lib/main.dart` | `MergeCountApp` / `_MergeCountAppState` | `ConnectMergeApp` / `_ConnectMergeAppState` |
| `lib/infrastructure/hive_storage_service.dart` | `_boxName = 'merge_count'` | `_boxName = 'connect_merge'` |
| `lib/infrastructure/score_sharer.dart` (channel) | `merge_count/facebook_share` | `connect_merge/facebook_share` |
| `lib/infrastructure/score_sharer.dart` (temp file) | `merge_count_score.png` | `connect_merge_score.png` |
| `android/.../MainActivity.kt` (channel) | `merge_count/facebook_share` | `connect_merge/facebook_share` |
| `lib/domain/models/duel_challenge.dart` (scheme) | `mergecount://` | `connectmerge://` |
| `lib/infrastructure/deep_link_service.dart` (scheme) | `mergecount://` | `connectmerge://` |
| `lib/infrastructure/friends_service.dart` (invite link) | `mergecount://invite/` | `connectmerge://invite/` |

**Note on Hive box rename:** Renaming `_boxName` from `merge_count` to `connect_merge` orphans any locally saved data on devices that already have the old box. Since the app is unpublished this is a clean break. If a live migration is ever needed, a one-time startup step reads the old box and copies it to the new one.

**Verification:** After rename — `flutter analyze` clean; `flutter test` passes; grep for `merge_loop|merge_count|MergeLoop|MergeCount|mergeloop|mergecount` in `lib/` and `android/` returns zero hits outside preserved historical docs.

---

## 4. Weekly top-3 prizes

### 4.1 Mechanism

On each app open, the client runs a one-shot prize check (idempotent — safe to run every launch):

1. Compute `lastMonday` = the most recent Monday in UTC (i.e., last week's Monday if today is Tuesday–Sunday, or this week's Monday if today is Monday).
2. If `PlayerProfile.lastWeeklyPrizeDate == lastMonday`, skip — already checked this week.
3. For each `Difficulty` tier, call `LeaderboardService.fetchPeriod(from: lastMonday, to: lastSunday)` where `lastSunday = lastMonday + 6 days`.
4. Find the entry where `isMe == true`.
5. If `rank <= 3`, grant the prize and persist `lastWeeklyPrizeDate = lastMonday`.

Coins are credited via the existing `onCoinsEarned` wallet hook. Running on every app open (not just Mondays) ensures players who skip Monday still receive prizes when they next launch.

### 4.2 Prize structure

| Rank | Coins | Badge |
|---|---|---|
| 1st | 500 | 🥇 permanent gold crown |
| 2nd | 250 | 🥈 silver crown |
| 3rd | 100 | 🥉 bronze crown |

### 4.3 Data model additions

```dart
// PlayerProfile gains:
final String? lastWeeklyPrizeDate;      // "YYYY-MM-DD" ISO week-start, claim guard
final List<WeeklyPrize> weeklyPrizes;   // permanent crown history

// New value object:
class WeeklyPrize {
  final String weekStart;   // "YYYY-MM-DD" Monday
  final Difficulty tier;
  final int rank;           // 1, 2, or 3
}
```

Both fields are migration-free (default `null` / empty list) following the established `PlayerProfile` pattern.

### 4.4 UI additions

- **`LeaderboardRow`**: optional crown icon prefix (gold/silver/bronze) when the row entry holds a prize for the currently displayed week.
- **Leaderboard screen**: "Your Crowns" section listing past weekly wins (week, tier, rank).
- **On prize grant**: one-time `SnackBar` toast — "You placed #1 last week on Hard — 500 coins awarded!"

### 4.5 What this deliberately does NOT do

- No server cron job — purely client-side.
- No real-money prizes.
- Only checks the immediately previous week — no retroactive multi-week sweep.

---

## 5. Daily Challenge mode

### 5.1 Overview

A sixth game mode added as `Difficulty.challenge`. It unlocks at noon UTC daily, plays a special-rule board seeded from `"$date:challenge"`, submits through the existing `submit-score` Edge Function and `leaderboard` RPC, and pays bonus coins to the top-10 players at the midnight reset. Noon unlock and payout are both enforced client-side.

### 5.2 Rule set

The daily rule is selected deterministically:

```dart
final ruleIndex = Prng(DailySeeder.seedForKey('$date:challenge')).nextInt(6);
final rule = ChallengeRule.values[ruleIndex];
```

Every player on a given date faces the same rule — same fairness guarantee as the daily board.

| Index | Rule | Mechanical effect |
|---|---|---|
| 0 | **Budget Cut** | 15 moves instead of 30 |
| 1 | **Long Chains Only** | `isValidChain` rejects paths of length < 3 |
| 2 | **Dense Start** | Starting fill = 14 tiles |
| 3 | **Sparse Start** | Starting fill = 3 tiles |
| 4 | **Wall Maze** | 8 seed-placed wall cells (existing wall system) |
| 5 | **Combo Rush** | `comboMultiplier(N)` doubled for chains of length ≥ 3 only; 2-tile chains score normally |

All six rules are replay-safe — the Edge Function re-derives `ruleIndex` from the same seed and re-validates moves against it.

### 5.3 Noon unlock

The challenge card on `TierSelectScreen` shows a live countdown (`"Opens in HH:MM:SS"`) until noon UTC, reusing the existing per-second `_ticker`. The card becomes tappable when `DateTime.now().toUtc().hour >= 12`. After midnight it locks again and the countdown resets for the next day.

### 5.4 Score submission and leaderboard

`GameCubit.init(difficulty: Difficulty.challenge)` seeds via `DailySeeder('$date', Difficulty.challenge)` with key `"$date:challenge"`. On completion, `submit-score` is called with `difficulty: 'challenge'`. The challenge leaderboard is daily-only (no weekly/monthly tabs) — it resets at midnight UTC with the board.

### 5.5 Top-10 payout

On each app open, if `PlayerProfile.lastChallengeCheckDate != yesterday`:

1. Fetch yesterday's challenge leaderboard via `LeaderboardService.fetch(difficulty: Difficulty.challenge, date: yesterday)`.
2. Find entry where `isMe == true`.
3. If `rank <= 10`, grant coins via the wallet hook and persist `lastChallengeCheckDate = yesterday`.

| Rank | Coins |
|---|---|
| 1st | 150 |
| 2nd–3rd | 100 |
| 4th–10th | 50 |

### 5.6 Data model additions

```dart
// Difficulty enum gains:
challenge

// New enum:
enum ChallengeRule {
  budgetCut,        // 0
  longChainsOnly,   // 1
  denseStart,       // 2
  sparseStart,      // 3
  wallMaze,         // 4
  comboRush,        // 5
}

// DailySeeder gains:
ChallengeRule challengeRule();  // derived from "$date:challenge" sub-stream

// PlayerProfile gains:
final String? lastChallengeCheckDate;  // "YYYY-MM-DD" of last payout check (yesterday guard)
```

`lastChallengeCheckDate` is migration-free (default `null`).

### 5.7 UI changes

- **`TierSelectScreen`**: New challenge card below the 4 tier cards.
  - Before noon: locked state with countdown timer and today's rule name (teaser).
  - After noon, not yet played: rule label + "Play" button.
  - After noon, completed: "Done ✓" + "Leaderboard" button.
- **`GameScreen`** (challenge mode): Rule banner at top — e.g., `"Today: Long Chains Only"`.
- **`LeaderboardScreen`**: New "Challenge" tab; shows top-10 only; coin prize indicators (🏆 ranks 1–3, ✦ ranks 4–10).

### 5.8 Edge Function update

The TypeScript `submit-score` function needs three additions:

1. Recognise `difficulty === 'challenge'` and use `seedForKey("$date:challenge")` for board generation.
2. Derive `ruleIndex = Prng(seedForKey("$date:challenge")).nextInt(6)` to identify today's rule.
3. Apply rule validation:
   - `budgetCut`: cap valid move count at 15.
   - `longChainsOnly`: reject `ChainEvent` paths of length < 3.
   - `denseStart` / `sparseStart`: use the correct `startingFill` (14 / 3) when regenerating the initial board.
   - `wallMaze`: use 8 walls when placing the seeded walls.
   - `comboRush`: double `comboMultiplier(N)` for `N >= 3` when computing the verified score.

---

## 6. Testing strategy

### Bug fixes
- Share button: manual device test — share button opens OS sheet on Android and iOS.
- Leaderboard: complete display-name flow on a fresh install; verify the name appears on the global leaderboard after a completed run.

### Rename
- `flutter analyze` — zero issues.
- `flutter test` — full suite passes.
- `grep -rE 'merge_loop|merge_count|MergeLoop|MergeCount|mergeloop|mergecount' lib/ android/` — zero matches outside preserved historical docs.

### Weekly prizes
- Unit test: `WeeklyPrize` round-trips through JSON; `lastWeeklyPrizeDate` guard prevents double-grant.
- Manual: simulate a top-3 finish by mocking `fetchPeriod`; verify coin grant fires exactly once per week.

### Daily Challenge
- Unit tests:
  - Same date + `"$date:challenge"` key → identical `ChallengeRule` across runs (determinism).
  - `longChainsOnly`: `isValidChain` rejects length-2 paths.
  - `comboRush`: multiplier doubled for N≥3, unchanged for N=2.
  - `lastChallengeCheckDate` guard: payout fires once per day.
- Manual:
  - Challenge card locked before noon, unlocked after noon.
  - Completing a challenge posts to the `challenge` leaderboard.
  - Top-10 payout fires correctly on the following day's app open.

---

## 7. Non-goals

- Endless Climb mode (Phase 5 of the engagement spec) — still behind the decision gate.
- Real-money prizes for weekly or challenge winners.
- Retroactive weekly prize sweeps for past weeks.
- Cross-move combo streak multiplier (deferred per the Connect-Merge design spec).
- Dart package name rename (`name:` in `pubspec.yaml`) — 177-import churn with no user-visible benefit.
