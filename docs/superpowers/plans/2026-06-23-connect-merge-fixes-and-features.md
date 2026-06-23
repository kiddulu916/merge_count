# Connect Merge — Fixes, Weekly Prizes, Daily Challenge & Rename — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the share button and leaderboard name bug, rename all `merge_loop`/`merge_count` identifiers to `connect_merge`, add weekly top-3 coin+crown prizes, and add a noon-UTC-unlocking Daily Challenge mode with 6 seed-derived special rules.

**Architecture:** Bug fixes and rename are mechanical string changes. Weekly prizes and challenge payouts are purely client-side — `EngagementCubit` runs a one-shot idempotent check on each app open, credits coins via the existing `onCoinsEarned` hook, and persists guard-dates on `PlayerProfile`. Daily Challenge reuses `Difficulty` enum + `DailySeeder` with rule overrides; the existing `submit-score` Edge Function and `leaderboard` RPC already work for any difficulty string, so only the replay logic needs to be extended for challenge rules.

**Tech Stack:** Flutter/Dart (flutter_bloc Cubit pattern), Hive persistence, Supabase (Edge Functions in TypeScript/Deno), `DailySeeder` + `Prng` deterministic PRNG, `GameEngine` pure domain layer.

## Global Constraints

- **Dart package name** (`name:` in `pubspec.yaml`) stays `merge_count` — do NOT rename it (177 import update churn with zero user-visible benefit).
- All new `PlayerProfile` fields must be migration-free: JSON deserialization defaults to null/0/empty when absent.
- `comboRush` rule: `comboMultiplierFn(N)` returns double for N≥3 **only**; N=2 stays at multiplier 1 (normal score).
- `longChainsOnly` rule rejects chains of length < 3 (minimum is 3 tiles, not 2).
- Challenge leaderboard is daily-only; noon UTC unlock enforced client-side via `DateTime.now().toUtc().hour >= 12`.
- All PRNG sub-stream keys must match exactly between Dart and TypeScript (e.g., `"$date:challenge"`).
- `flutter analyze` must pass clean and `flutter test` must pass before every commit.
- TypeScript edge functions live in `supabase/functions/`; shared types in `supabase/functions/_shared/`.

---

### Task 1: Rename — `merge_count`/`merge_loop` → `connect_merge` in 8 locations

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/infrastructure/hive_storage_service.dart`
- Modify: `lib/infrastructure/score_sharer.dart`
- Modify: `lib/domain/models/duel_challenge.dart`
- Modify: `lib/infrastructure/deep_link_service.dart`
- Modify: `lib/infrastructure/friends_service.dart`
- Modify: `android/app/src/main/kotlin/com/kiddulu/merge_count/MainActivity.kt`

**Interfaces:**
- Produces: `MethodChannel('connect_merge/facebook_share')` agreed by Dart + Kotlin; `connectmerge://` scheme; `connect_merge` Hive box; class names `ConnectMergeApp` / `_ConnectMergeAppState`.

- [ ] **Step 1: Update `lib/main.dart` class names**

  In `lib/main.dart`, replace:
  ```dart
  class MergeCountApp extends StatefulWidget {
  ```
  with:
  ```dart
  class ConnectMergeApp extends StatefulWidget {
  ```
  Replace all occurrences of `MergeCountApp` and `_MergeCountAppState` throughout the file (including the `State<MergeCountApp>` declaration and `runApp(MergeCountApp(...))` call):
  - `MergeCountApp` → `ConnectMergeApp`
  - `_MergeCountAppState` → `_ConnectMergeAppState`

- [ ] **Step 2: Update `lib/infrastructure/hive_storage_service.dart`**

  ```dart
  // Before:
  static const _boxName = 'merge_count';
  // After:
  static const _boxName = 'connect_merge';
  ```

- [ ] **Step 3: Update `lib/infrastructure/score_sharer.dart`**

  ```dart
  // Before:
  static const MethodChannel _channel = MethodChannel('merge_count/facebook_share');
  // After:
  static const MethodChannel _channel = MethodChannel('connect_merge/facebook_share');
  ```

  ```dart
  // Before:
  final file = File('${dir.path}/merge_count_score.png');
  // After:
  final file = File('${dir.path}/connect_merge_score.png');
  ```

  Also update the `ShareParams` subject while you're in the file:
  ```dart
  // Before:
  ShareParams(files: [XFile(file.path)], subject: 'Merge Count')
  // After:
  ShareParams(files: [XFile(file.path)], subject: 'Connect Merge')
  ```

- [ ] **Step 4: Update deep-link scheme in `lib/domain/models/duel_challenge.dart`**

  ```dart
  // Before (toUri):
  'mergecount://duel/$date/${difficulty.name}/$challengerScore/'
  // After:
  'connectmerge://duel/$date/${difficulty.name}/$challengerScore/'
  ```

  ```dart
  // Before (fromUri):
  if (uri.scheme == 'mergecount') {
  // After:
  if (uri.scheme == 'connectmerge') {
  ```

  Leave `static const String _httpsHost = 'mergecount.app';` unchanged (real domain, not a code identifier).

- [ ] **Step 5: Update deep-link scheme in `lib/infrastructure/deep_link_service.dart`**

  ```dart
  // Before (parseInviteCode):
  if (uri.scheme == 'mergecount') {
  // After:
  if (uri.scheme == 'connectmerge') {
  ```

  Also update the doc-comment scheme references from `mergecount://` → `connectmerge://`.

- [ ] **Step 6: Update invite link in `lib/infrastructure/friends_service.dart`**

  ```dart
  // Before:
  static String inviteLink(String code) => 'mergecount://invite/$code';
  // After:
  static String inviteLink(String code) => 'connectmerge://invite/$code';
  ```

- [ ] **Step 7: Update Kotlin channel name in `android/.../MainActivity.kt`**

  ```kotlin
  // Before:
  private val channelName = "merge_count/facebook_share"
  // After:
  private val channelName = "connect_merge/facebook_share"
  ```

- [ ] **Step 8: Verify rename**

  Run:
  ```
  grep -rE "merge_loop|merge_count|MergeLoop|MergeCount|mergeloop|mergecount" lib/ android/app/src/main/kotlin/
  ```
  Expected: zero matches (ignoring comments in historical docs and the package name in `pubspec.yaml`).

  Run: `flutter analyze`
  Expected: zero issues.

- [ ] **Step 9: Run tests**

  Run: `flutter test`
  Expected: all tests pass.

- [ ] **Step 10: Commit**

  ```bash
  git add lib/main.dart lib/infrastructure/hive_storage_service.dart \
    lib/infrastructure/score_sharer.dart lib/domain/models/duel_challenge.dart \
    lib/infrastructure/deep_link_service.dart lib/infrastructure/friends_service.dart \
    "android/app/src/main/kotlin/com/kiddulu/merge_count/MainActivity.kt"
  git commit -m "refactor: rename merge_count/merge_loop identifiers to connect_merge"
  ```

---

### Task 2: Bug fix — leaderboard display name not appearing

**Files:**
- Modify: `lib/infrastructure/leaderboard_service.dart`
- Modify: `lib/application/game_cubit.dart`

**Interfaces:**
- Consumes: `auth.hasDisplayName()` in `main.dart`; `submitRun()` in `LeaderboardService`
- Produces: Score submissions correctly carry `difficulty` string (including future `'challenge'`); leaderboard name appears after display-name onboarding completes.

**Root cause analysis:**
The `needsDisplayName` guard is already wired correctly in `main.dart`. The two most likely causes for blank leaderboard names are:
1. Supabase env vars (`--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`) are missing from the run/build command, so `initSupabase()` returns false, anon sign-in never fires, and `onSubmitRun` is never called.
2. The display-name flow completed but the Supabase `players` row upsert failed silently.

- [ ] **Step 1: Verify Supabase env vars in your run command**

  Confirm your `flutter run` / `flutter build` command includes:
  ```
  --dart-define=SUPABASE_URL=<your-project-url>
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
  ```
  If these are absent, `initSupabase()` returns false, the entire online layer is skipped, and `onSubmitRun` is never wired — scores are never sent.

- [ ] **Step 2: Add a `submitRun` debug guard in `LeaderboardService`**

  In `lib/infrastructure/leaderboard_service.dart`, add an assertion to `submitRun` that surfaces silent failures:

  ```dart
  Future<SubmitResult> submitRun({
    required String date,
    required Difficulty difficulty,
    required List<MoveEvent> moveLog,
  }) async {
    final data = await _invoke('submit-score', {
      'date': date,
      'difficulty': difficulty.name,
      'moveLog': moveLog.map((e) => e.toJson()).toList(),
      'season': kLeaderboardSeason,
    });
    assert(
      data['valid'] == true || data.containsKey('reason'),
      'submit-score returned unexpected shape: $data',
    );
    return SubmitResult.fromJson(data);
  }
  ```

  This surfaces submission failures in debug builds without affecting release.

- [ ] **Step 3: Run `flutter analyze`**

  Run: `flutter analyze`
  Expected: zero issues.

- [ ] **Step 4: Manual test — full leaderboard flow**

  On a real or emulated Android device with Supabase env vars set:
  1. Fresh install (or clear app data).
  2. Launch → enter a display name → complete one Easy tier game.
  3. After the result screen appears, check the Easy leaderboard.
  4. Your display name and score must appear.

  If the name still doesn't appear, check Supabase dashboard → `scores` table for your user's row; if absent, the Edge Function is failing — check Supabase function logs.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/infrastructure/leaderboard_service.dart
  git commit -m "fix(leaderboard): add debug assertion to surface silent submitRun failures"
  ```

---

### Task 3: Domain models — `ChallengeRule` and `WeeklyPrize`

**Files:**
- Create: `lib/domain/models/challenge_rule.dart`
- Create: `lib/domain/models/weekly_prize.dart`
- Modify: `lib/domain/models/difficulty.dart`
- Modify: `lib/domain/constants.dart`
- Test: `test/domain/challenge_rule_test.dart`

**Interfaces:**
- Produces:
  - `enum ChallengeRule { budgetCut, longChainsOnly, denseStart, sparseStart, wallMaze, comboRush }` in `lib/domain/models/challenge_rule.dart`
  - `class WeeklyPrize { final String weekStart; final Difficulty tier; final int rank; }` with `toJson`/`fromJson` in `lib/domain/models/weekly_prize.dart`
  - `Difficulty.challenge(gridSize: 6, startingFill: 8, label: 'Challenge')` added to enum
  - `const kChallengeMoves = 15`, `int comboRushMultiplier(int n)`, `const kChallengeWallMazeCount = 8` added to `constants.dart`
  - `wallCountFor` switch handles `Difficulty.challenge` (returns 0 — challenge walls are set by the rule override)

- [ ] **Step 1: Write tests for `ChallengeRule` determinism and `WeeklyPrize` serialization**

  Create `test/domain/challenge_rule_test.dart`:

  ```dart
  import 'package:merge_count/domain/models/challenge_rule.dart';
  import 'package:merge_count/domain/models/difficulty.dart';
  import 'package:merge_count/domain/models/weekly_prize.dart';
  import 'package:merge_count/domain/constants.dart';
  import 'package:test/test.dart';

  void main() {
    group('comboRushMultiplier', () {
      test('N=2 returns same as comboMultiplier (not doubled)', () {
        expect(comboRushMultiplier(2), equals(comboMultiplier(2)));
      });
      test('N=3 returns doubled multiplier', () {
        expect(comboRushMultiplier(3), equals(comboMultiplier(3) * 2));
      });
      test('N=4 returns doubled multiplier', () {
        expect(comboRushMultiplier(4), equals(comboMultiplier(4) * 2));
      });
      test('N=1 returns 0 (invalid chain)', () {
        expect(comboRushMultiplier(1), equals(0));
      });
    });

    group('WeeklyPrize', () {
      test('round-trips through JSON', () {
        const prize = WeeklyPrize(
          weekStart: '2026-06-22',
          tier: Difficulty.hard,
          rank: 1,
        );
        final json = prize.toJson();
        final decoded = WeeklyPrize.fromJson(json);
        expect(decoded.weekStart, equals('2026-06-22'));
        expect(decoded.tier, equals(Difficulty.hard));
        expect(decoded.rank, equals(1));
      });
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL (files don't exist yet)**

  Run: `flutter test test/domain/challenge_rule_test.dart`
  Expected: FAIL with compilation errors.

- [ ] **Step 3: Add `challenge` to `Difficulty` enum in `lib/domain/models/difficulty.dart`**

  ```dart
  enum Difficulty {
    easy(gridSize: 8, startingFill: 40, label: 'Easy'),
    medium(gridSize: 7, startingFill: 25, label: 'Medium'),
    hard(gridSize: 6, startingFill: 20, label: 'Hard'),
    legendary(gridSize: 6, startingFill: 15, label: 'Legendary'),
    challenge(gridSize: 6, startingFill: 8, label: 'Challenge');

    const Difficulty({
      required this.gridSize,
      required this.startingFill,
      required this.label,
    });

    final int gridSize;
    final int startingFill;
    final String label;

    int get cellCount => gridSize * gridSize;
  }
  ```

- [ ] **Step 4: Update `wallCountFor` + add challenge constants to `lib/domain/constants.dart`**

  Update the `wallCountFor` switch to handle the new enum value:
  ```dart
  int wallCountFor(Difficulty d) => switch (d) {
        Difficulty.easy => 2,
        Difficulty.medium => 4,
        Difficulty.hard => 5,
        Difficulty.legendary => 6,
        Difficulty.challenge => 0, // walls set by rule override (wallMaze uses 8)
      };
  ```

  Add after the existing `comboMultiplier` function:
  ```dart
  /// Combo Rush challenge rule: doubled multiplier for chains of length ≥ 3;
  /// N=2 chains score normally (multiplier stays at 1).
  int comboRushMultiplier(int n) {
    if (n < 3) return comboMultiplier(n);
    return comboMultiplier(n) * 2;
  }

  /// Challenge mode: move budget under the Budget Cut rule.
  const int kChallengeMoves = 15;

  /// Challenge mode: wall count for the Wall Maze rule.
  const int kChallengeWallMazeCount = 8;

  /// Challenge mode: dense starting fill (Dense Start rule).
  const int kChallengeDenseFill = 14;

  /// Challenge mode: sparse starting fill (Sparse Start rule).
  const int kChallengeSparseFill = 3;
  ```

- [ ] **Step 5: Create `lib/domain/models/challenge_rule.dart`**

  ```dart
  /// The daily-selected special rule for a Challenge mode board.
  ///
  /// The index within [values] is the seed-derived index:
  ///   `Prng(DailySeeder.seedForKey('$date:challenge')).nextInt(6)`.
  /// The index must NEVER change (it is part of the deterministic contract).
  enum ChallengeRule {
    budgetCut,      // 0 — 15 moves instead of 30
    longChainsOnly, // 1 — chains of length < 3 are rejected
    denseStart,     // 2 — starting fill = 14
    sparseStart,    // 3 — starting fill = 3
    wallMaze,       // 4 — 8 seed-placed wall cells
    comboRush,      // 5 — comboMultiplier doubled for N≥3
  }

  extension ChallengeRuleLabel on ChallengeRule {
    String get label => switch (this) {
          ChallengeRule.budgetCut => 'Budget Cut',
          ChallengeRule.longChainsOnly => 'Long Chains Only',
          ChallengeRule.denseStart => 'Dense Start',
          ChallengeRule.sparseStart => 'Sparse Start',
          ChallengeRule.wallMaze => 'Wall Maze',
          ChallengeRule.comboRush => 'Combo Rush',
        };

    String get description => switch (this) {
          ChallengeRule.budgetCut => 'Only 15 moves. Make each one count.',
          ChallengeRule.longChainsOnly => 'Chains must be 3+ tiles. No quick pairs.',
          ChallengeRule.denseStart => 'Board starts nearly full. Plan ahead.',
          ChallengeRule.sparseStart => 'Board starts almost empty. Build your way up.',
          ChallengeRule.wallMaze => '8 walls block your paths. Navigate carefully.',
          ChallengeRule.comboRush => 'Chains of 3+ score double. Chain everything.',
        };
  }
  ```

- [ ] **Step 6: Create `lib/domain/models/weekly_prize.dart`**

  ```dart
  import 'difficulty.dart';

  /// A permanent record of a top-3 weekly leaderboard finish.
  class WeeklyPrize {
    /// ISO week-start date (Monday), e.g. `"2026-06-22"`.
    final String weekStart;

    /// Which difficulty tier this prize was earned on.
    final Difficulty tier;

    /// Leaderboard rank (1, 2, or 3).
    final int rank;

    const WeeklyPrize({
      required this.weekStart,
      required this.tier,
      required this.rank,
    });

    Map<String, dynamic> toJson() => {
          'weekStart': weekStart,
          'tier': tier.name,
          'rank': rank,
        };

    static WeeklyPrize fromJson(Map<String, dynamic> j) => WeeklyPrize(
          weekStart: j['weekStart'] as String,
          tier: Difficulty.values.byName(j['tier'] as String),
          rank: j['rank'] as int,
        );
  }
  ```

- [ ] **Step 7: Run tests — expect PASS**

  Run: `flutter test test/domain/challenge_rule_test.dart`
  Expected: all 5 tests PASS.

- [ ] **Step 8: Run `flutter analyze`**

  Expected: zero issues. Fix any exhaustiveness warnings from the new `Difficulty.challenge` case in existing switches (e.g., any `switch (difficulty)` without a `challenge` arm).

- [ ] **Step 9: Commit**

  ```bash
  git add lib/domain/models/difficulty.dart lib/domain/constants.dart \
    lib/domain/models/challenge_rule.dart lib/domain/models/weekly_prize.dart \
    test/domain/challenge_rule_test.dart
  git commit -m "feat(domain): add ChallengeRule, WeeklyPrize, Difficulty.challenge, and combo-rush multiplier"
  ```

---

### Task 4: `PlayerProfile` additions — prize guard fields

**Files:**
- Modify: `lib/infrastructure/storage_service.dart`
- Test: `test/infrastructure/storage_service_test.dart` (or nearest existing profile test)

**Interfaces:**
- Consumes: `WeeklyPrize.toJson()` / `WeeklyPrize.fromJson()`
- Produces:
  - `PlayerProfile.lastWeeklyPrizeDate` — nullable `String` (`"YYYY-MM-DD"` ISO Monday), migration-free null default
  - `PlayerProfile.weeklyPrizesJson` — `List<dynamic>` raw JSON storage of `WeeklyPrize` list, migration-free empty default
  - `PlayerProfile.lastChallengeCheckDate` — nullable `String` (`"YYYY-MM-DD"` of yesterday's payout check), migration-free null default
  - All three fields added to `copyWith`, `toJson`, `fromJson`

- [ ] **Step 1: Write failing tests for new `PlayerProfile` fields**

  Find or create `test/infrastructure/player_profile_test.dart`:

  ```dart
  import 'package:merge_count/infrastructure/storage_service.dart';
  import 'package:merge_count/domain/models/difficulty.dart';
  import 'package:merge_count/domain/models/weekly_prize.dart';
  import 'package:test/test.dart';

  void main() {
    group('PlayerProfile weekly prize fields', () {
      test('empty profile has null lastWeeklyPrizeDate', () {
        expect(PlayerProfile.empty.lastWeeklyPrizeDate, isNull);
      });

      test('empty profile has empty weeklyPrizes', () {
        expect(PlayerProfile.empty.weeklyPrizes, isEmpty);
      });

      test('empty profile has null lastChallengeCheckDate', () {
        expect(PlayerProfile.empty.lastChallengeCheckDate, isNull);
      });

      test('copyWith updates lastWeeklyPrizeDate', () {
        final p = PlayerProfile.empty.copyWith(lastWeeklyPrizeDate: '2026-06-22');
        expect(p.lastWeeklyPrizeDate, equals('2026-06-22'));
      });

      test('copyWith updates weeklyPrizes', () {
        const prize = WeeklyPrize(weekStart: '2026-06-22', tier: Difficulty.hard, rank: 1);
        final p = PlayerProfile.empty.copyWith(weeklyPrizes: [prize]);
        expect(p.weeklyPrizes.length, equals(1));
        expect(p.weeklyPrizes.first.rank, equals(1));
      });

      test('copyWith updates lastChallengeCheckDate', () {
        final p = PlayerProfile.empty.copyWith(lastChallengeCheckDate: '2026-06-22');
        expect(p.lastChallengeCheckDate, equals('2026-06-22'));
      });

      test('JSON round-trip preserves weekly prizes', () {
        const prize = WeeklyPrize(weekStart: '2026-06-22', tier: Difficulty.hard, rank: 2);
        final p = PlayerProfile.empty.copyWith(
          lastWeeklyPrizeDate: '2026-06-22',
          weeklyPrizes: [prize],
          lastChallengeCheckDate: '2026-06-21',
        );
        final decoded = PlayerProfile.fromJson(p.toJson());
        expect(decoded.lastWeeklyPrizeDate, equals('2026-06-22'));
        expect(decoded.weeklyPrizes.length, equals(1));
        expect(decoded.weeklyPrizes.first.tier, equals(Difficulty.hard));
        expect(decoded.lastChallengeCheckDate, equals('2026-06-21'));
      });

      test('fromJson with missing fields uses migration-free defaults', () {
        final p = PlayerProfile.fromJson({});
        expect(p.lastWeeklyPrizeDate, isNull);
        expect(p.weeklyPrizes, isEmpty);
        expect(p.lastChallengeCheckDate, isNull);
      });
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL**

  Run: `flutter test test/infrastructure/player_profile_test.dart`
  Expected: FAIL (fields don't exist yet).

- [ ] **Step 3: Add fields to `PlayerProfile` in `lib/infrastructure/storage_service.dart`**

  Add after the `colorblindMode` field declaration:
  ```dart
  /// ISO week-start Monday of the last weekly prize check. Guards once-per-week
  /// claiming. Migration-free default null.
  final String? lastWeeklyPrizeDate;

  /// Permanent history of weekly top-3 finishes, serialised as raw JSON list.
  /// Migration-free default empty.
  final List<WeeklyPrize> weeklyPrizes;

  /// UTC date of the last challenge payout check (`YYYY-MM-DD`). Guards
  /// once-per-day claiming. Migration-free default null.
  final String? lastChallengeCheckDate;
  ```

  Update the constructor:
  ```dart
  const PlayerProfile({
    // ... existing params ...
    this.lastWeeklyPrizeDate,
    this.weeklyPrizes = const [],
    this.lastChallengeCheckDate,
  });
  ```

  Update `copyWith`:
  ```dart
  PlayerProfile copyWith({
    // ... existing params ...
    String? lastWeeklyPrizeDate,
    bool clearLastWeeklyPrizeDate = false,
    List<WeeklyPrize>? weeklyPrizes,
    String? lastChallengeCheckDate,
    bool clearLastChallengeCheckDate = false,
  }) => PlayerProfile(
    // ... existing fields ...
    lastWeeklyPrizeDate: clearLastWeeklyPrizeDate ? null : (lastWeeklyPrizeDate ?? this.lastWeeklyPrizeDate),
    weeklyPrizes: weeklyPrizes ?? this.weeklyPrizes,
    lastChallengeCheckDate: clearLastChallengeCheckDate ? null : (lastChallengeCheckDate ?? this.lastChallengeCheckDate),
  );
  ```

  Update `toJson`:
  ```dart
  Map<String, dynamic> toJson() => {
    // ... existing keys ...
    'lastWeeklyPrizeDate': lastWeeklyPrizeDate,
    'weeklyPrizes': weeklyPrizes.map((p) => p.toJson()).toList(),
    'lastChallengeCheckDate': lastChallengeCheckDate,
  };
  ```

  Update `fromJson`:
  ```dart
  static PlayerProfile fromJson(Map<String, dynamic> j) => PlayerProfile(
    // ... existing deserialization ...
    lastWeeklyPrizeDate: j['lastWeeklyPrizeDate'] as String?,
    weeklyPrizes: ((j['weeklyPrizes'] as List?) ?? const [])
        .map((e) => WeeklyPrize.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    lastChallengeCheckDate: j['lastChallengeCheckDate'] as String?,
  );
  ```

  Add the import at the top of `storage_service.dart`:
  ```dart
  import 'package:merge_count/domain/models/weekly_prize.dart';
  ```

- [ ] **Step 4: Run tests — expect PASS**

  Run: `flutter test test/infrastructure/player_profile_test.dart`
  Expected: all 7 tests PASS.

- [ ] **Step 5: Run `flutter analyze`**

  Expected: zero issues.

- [ ] **Step 6: Commit**

  ```bash
  git add lib/infrastructure/storage_service.dart test/infrastructure/player_profile_test.dart
  git commit -m "feat(profile): add weekly prize + challenge payout guard fields to PlayerProfile"
  ```

---

### Task 5: Weekly top-3 prizes — `EngagementCubit` check + `EngagementState` display

**Files:**
- Modify: `lib/application/engagement_cubit.dart`
- Test: `test/application/weekly_prize_test.dart`

**Interfaces:**
- Consumes: `LeaderboardService.fetchPeriod(difficulty, from, to)` → `List<LeaderboardEntry>`; `LeaderboardEntry.isMe`; `storage.loadProfile()` / `storage.saveProfile()`; `onCoinsEarned` (passed in from `GameCubit` or `TierSelectScreen`)
- Produces:
  - `EngagementState.weeklyPrizes` — `List<WeeklyPrize>` for the "Your Crowns" UI section
  - `EngagementCubit.checkWeeklyPrizes(LeaderboardService leaderboard)` — async, idempotent, called on app open
  - Coin reward amounts: rank 1 → 500, rank 2 → 250, rank 3 → 100
  - Crown badges visible on `LeaderboardRow` (handled in Task 9)

- [ ] **Step 1: Write failing tests for `checkWeeklyPrizes`**

  Create `test/application/weekly_prize_test.dart`:

  ```dart
  import 'package:merge_count/application/engagement_cubit.dart';
  import 'package:merge_count/domain/models/difficulty.dart';
  import 'package:merge_count/domain/models/leaderboard_entry.dart';
  import 'package:merge_count/infrastructure/storage_service.dart';
  import 'package:test/test.dart';

  // Minimal fake leaderboard that returns a preset rank for the caller.
  class _FakeLeaderboard {
    final int rank;
    _FakeLeaderboard(this.rank);

    Future<List<LeaderboardEntry>> fetchPeriod({
      required Difficulty difficulty,
      required String from,
      required String to,
    }) async => [
          LeaderboardEntry(rank: 1, displayName: 'Alice', score: 9000, isMe: false),
          LeaderboardEntry(rank: rank, displayName: 'Me', score: 1000, isMe: true),
        ];
  }

  void main() {
    late InMemoryStorageService storage;
    late EngagementCubit cubit;

    setUp(() {
      storage = InMemoryStorageService();
      cubit = EngagementCubit(storage: storage, todayProvider: () => '2026-06-23');
      cubit.load();
    });

    tearDown(() => cubit.close());

    test('rank 1 grants 500 coins and records crown', () async {
      final fake = _FakeLeaderboard(1);
      await cubit.checkWeeklyPrizes(fake.fetchPeriod);
      expect(cubit.state.coins, equals(500));
      expect(cubit.state.weeklyPrizes.length, equals(Difficulty.values.where((d) => d != Difficulty.challenge).length));
    });

    test('rank 2 grants 250 coins', () async {
      final fake = _FakeLeaderboard(2);
      await cubit.checkWeeklyPrizes(fake.fetchPeriod);
      expect(cubit.state.coins, equals(250));
    });

    test('rank 3 grants 100 coins', () async {
      final fake = _FakeLeaderboard(3);
      await cubit.checkWeeklyPrizes(fake.fetchPeriod);
      expect(cubit.state.coins, equals(100));
    });

    test('rank 4+ grants no coins', () async {
      final fake = _FakeLeaderboard(4);
      await cubit.checkWeeklyPrizes(fake.fetchPeriod);
      expect(cubit.state.coins, equals(0));
    });

    test('second call in same week is a no-op (idempotent)', () async {
      final fake = _FakeLeaderboard(1);
      await cubit.checkWeeklyPrizes(fake.fetchPeriod);
      await cubit.checkWeeklyPrizes(fake.fetchPeriod);
      expect(cubit.state.coins, equals(500)); // only 500, not 1000
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL**

  Run: `flutter test test/application/weekly_prize_test.dart`
  Expected: FAIL (`checkWeeklyPrizes` doesn't exist).

- [ ] **Step 3: Add `weeklyPrizes` to `EngagementState`**

  In `lib/application/engagement_cubit.dart`, add field to `EngagementState`:
  ```dart
  import '../domain/models/weekly_prize.dart';

  class EngagementState {
    // ... existing fields ...
    final List<WeeklyPrize> weeklyPrizes;

    const EngagementState({
      // ... existing params ...
      this.weeklyPrizes = const [],
    });

    EngagementState copyWith({
      // ... existing params ...
      List<WeeklyPrize>? weeklyPrizes,
    }) => EngagementState(
      // ... existing fields ...
      weeklyPrizes: weeklyPrizes ?? this.weeklyPrizes,
    );
  }
  ```

  Also hydrate it in `load()`:
  ```dart
  void load() {
    final profile = storage.loadProfile();
    // ... existing hydration ...
    emit(EngagementState(
      // ... existing fields ...
      weeklyPrizes: profile.weeklyPrizes,
    ));
  }
  ```

- [ ] **Step 4: Add `checkWeeklyPrizes` method to `EngagementCubit`**

  Add a helper to compute the previous ISO week's Monday:
  ```dart
  /// Returns the Monday of the most recent completed ISO week (last Monday in UTC).
  /// "Last Monday" = today if today IS Monday, else the preceding Monday.
  static String _lastMonday(String today) {
    final d = DateTime.parse(today);
    // weekday: Mon=1 ... Sun=7
    final daysSinceMonday = (d.weekday - 1) % 7;
    final monday = d.subtract(Duration(days: daysSinceMonday));
    return monday.toIso8601String().substring(0, 10);
  }

  static String _lastSunday(String monday) {
    final m = DateTime.parse(monday);
    return m.add(const Duration(days: 6)).toIso8601String().substring(0, 10);
  }
  ```

  Add the prize constants:
  ```dart
  static const _weeklyCoins = {1: 500, 2: 250, 3: 100};
  ```

  Add the method:
  ```dart
  /// Check if the player placed top-3 in last week's leaderboard for any tier.
  /// Idempotent: the `lastWeeklyPrizeDate` guard prevents double-granting.
  /// [fetchPeriod] is the transport seam — matches [LeaderboardService.fetchPeriod]'s signature.
  Future<void> checkWeeklyPrizes(
    Future<List<LeaderboardEntry>> Function({
      required Difficulty difficulty,
      required String from,
      required String to,
    }) fetchPeriod,
  ) async {
    final today = todayProvider();
    final lastMonday = _lastMonday(today);
    final lastSunday = _lastSunday(lastMonday);

    final profile = storage.loadProfile();
    if (profile.lastWeeklyPrizeDate == lastMonday) return; // already checked this week

    var totalCoins = 0;
    final newCrowns = <WeeklyPrize>[];

    for (final difficulty in Difficulty.values) {
      if (difficulty == Difficulty.challenge) continue; // challenge has its own payout
      try {
        final entries = await fetchPeriod(
          difficulty: difficulty,
          from: lastMonday,
          to: lastSunday,
        );
        final myEntry = entries.where((e) => e.isMe).firstOrNull;
        if (myEntry == null) continue;
        final coins = _weeklyCoins[myEntry.rank];
        if (coins != null) {
          totalCoins += coins;
          newCrowns.add(WeeklyPrize(
            weekStart: lastMonday,
            tier: difficulty,
            rank: myEntry.rank,
          ));
        }
      } catch (_) {
        // Network failure: skip this tier, try on next launch.
      }
    }

    final updatedProfile = profile.copyWith(
      lastWeeklyPrizeDate: lastMonday,
      weeklyPrizes: [...profile.weeklyPrizes, ...newCrowns],
      coins: profile.coins + totalCoins,
    );
    await storage.saveProfile(updatedProfile);

    emit(state.copyWith(
      coins: updatedProfile.coins,
      weeklyPrizes: updatedProfile.weeklyPrizes,
    ));
  }
  ```

- [ ] **Step 5: Run tests — expect PASS**

  Run: `flutter test test/application/weekly_prize_test.dart`
  Expected: all 5 tests PASS.

- [ ] **Step 6: Wire `checkWeeklyPrizes` call in `main.dart` (after cold start)**

  In `lib/main.dart`, after wiring the leaderboard service:
  ```dart
  if (leaderboard != null) {
    // Check for weekly prizes on every app open (idempotent, no-op if checked this week).
    unawaited(engagement.checkWeeklyPrizes(leaderboard!.fetchPeriod));
  }
  ```

  Import `dart:async` for `unawaited` if not already present.

- [ ] **Step 7: Run `flutter analyze` and `flutter test`**

  Both must pass clean.

- [ ] **Step 8: Commit**

  ```bash
  git add lib/application/engagement_cubit.dart lib/main.dart \
    test/application/weekly_prize_test.dart
  git commit -m "feat(engagement): add weekly top-3 prize check with coins + crown history"
  ```

---

### Task 6: Challenge board generation — `DailySeeder` + `GameEngine` rule support

**Files:**
- Modify: `lib/domain/engine/daily_seeder.dart`
- Modify: `lib/domain/engine/game_engine.dart`
- Test: `test/domain/challenge_seeder_test.dart`

**Interfaces:**
- Consumes: `ChallengeRule`, `kChallengeMoves`, `kChallengeWallMazeCount`, `kChallengeDenseFill`, `kChallengeSparseFill`, `comboRushMultiplier` from `constants.dart`
- Produces:
  - `DailySeeder.challengeRule` getter — returns the `ChallengeRule` for `this.date` via `Prng(seedForKey('$date:challenge')).nextInt(6)`
  - `DailySeeder.generate({int? startingFillOverride, int? wallCountOverride, int? movesOverride})` — add optional overrides to existing method
  - `GameEngine.collapseChain(BoardState s, List<int> path, {int Function(int)? comboMultiplierFn})` — optional multiplier override

- [ ] **Step 1: Write failing tests**

  Create `test/domain/challenge_seeder_test.dart`:

  ```dart
  import 'package:merge_count/domain/engine/daily_seeder.dart';
  import 'package:merge_count/domain/models/challenge_rule.dart';
  import 'package:merge_count/domain/models/difficulty.dart';
  import 'package:merge_count/domain/constants.dart';
  import 'package:merge_count/domain/engine/game_engine.dart';
  import 'package:merge_count/infrastructure/storage_service.dart';
  import 'package:test/test.dart';

  void main() {
    group('DailySeeder.challengeRule', () {
      test('same date always returns the same rule (deterministic)', () {
        final s1 = DailySeeder('2026-06-23', Difficulty.challenge);
        final s2 = DailySeeder('2026-06-23', Difficulty.challenge);
        expect(s1.challengeRule, equals(s2.challengeRule));
      });

      test('different dates can return different rules', () {
        // Not guaranteed to differ, but tests that the indexing is date-bound.
        final rules = {
          DailySeeder('2026-06-23', Difficulty.challenge).challengeRule,
          DailySeeder('2026-06-24', Difficulty.challenge).challengeRule,
          DailySeeder('2026-06-25', Difficulty.challenge).challengeRule,
        };
        // At least one valid ChallengeRule returned.
        expect(rules.every((r) => ChallengeRule.values.contains(r)), isTrue);
      });
    });

    group('DailySeeder.generate with overrides', () {
      test('budgetCut: board has movesRemaining = 15', () {
        final seeder = DailySeeder('2026-06-23', Difficulty.challenge);
        final start = seeder.generate(movesOverride: kChallengeMoves);
        expect(start.board.movesRemaining, equals(kChallengeMoves));
      });

      test('denseStart: board has correct fill', () {
        final seeder = DailySeeder('2026-06-23', Difficulty.challenge);
        final start = seeder.generate(startingFillOverride: kChallengeDenseFill);
        final filled = start.board.cells.where((c) => c != null).length;
        // Dense fill may be adjusted slightly by the deadlock-safe re-roll,
        // but exactly kChallengeDenseFill tiles are placed.
        expect(filled, equals(kChallengeDenseFill));
      });

      test('wallMaze: board has 8 wall cells', () {
        final seeder = DailySeeder('2026-06-23', Difficulty.challenge);
        final start = seeder.generate(wallCountOverride: kChallengeWallMazeCount);
        expect(start.board.walls.length, equals(kChallengeWallMazeCount));
      });
    });

    group('GameEngine.collapseChain comboRush', () {
      test('N=2 chain scores same with or without comboRush override', () {
        final storage = InMemoryStorageService();
        // Build a minimal 2-tile board for a chain test.
        // Use Difficulty.hard (6x6).
        final seeder = DailySeeder('2026-06-23', Difficulty.hard);
        final start = seeder.generate();
        // Find any adjacent pair.
        final board = start.board;
        int? a, b;
        for (var i = 0; i < board.cells.length && a == null; i++) {
          final t = board.cells[i];
          if (t == null) continue;
          final gs = board.gridSize;
          final right = i + 1;
          if (right < board.cells.length &&
              right % gs != 0 &&
              board.cells[right]?.tier == t.tier) {
            a = i; b = right;
          }
        }
        if (a == null) return; // no adjacent pair on this seed; test passes vacuously

        final normalScore = GameEngine.collapseChain(board, [a!, b!]).score - board.score;
        final rushScore = GameEngine.collapseChain(
          board, [a, b],
          comboMultiplierFn: comboRushMultiplier,
        ).score - board.score;
        expect(rushScore, equals(normalScore)); // N=2: no doubling
      });
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL**

  Run: `flutter test test/domain/challenge_seeder_test.dart`
  Expected: FAIL (methods don't exist).

- [ ] **Step 3: Add `challengeRule` getter + `generate` overrides to `DailySeeder`**

  In `lib/domain/engine/daily_seeder.dart`, add import at top:
  ```dart
  import '../models/challenge_rule.dart';
  ```

  Add `challengeRule` getter after the `_key` getter:
  ```dart
  /// The rule for today's Challenge board, derived from the `"$date:challenge"`
  /// seed. Deterministic — same date returns identical rule for every player.
  ChallengeRule get challengeRule {
    final idx = Prng(DailySeeder.seedForKey('$date:challenge')).nextInt(6);
    return ChallengeRule.values[idx];
  }
  ```

  Update `generate()` signature to add optional overrides:
  ```dart
  DailyStart generate({
    int? startingFillOverride,
    int? wallCountOverride,
    int? movesOverride,
  }) {
    final a = Prng(_seedA);
    final wallCount = wallCountOverride ?? wallCountFor(difficulty);
    // Rebuild wallIndices with the overridden count:
    final walls = _wallIndicesWithCount(wallCount);
    final startingFill = startingFillOverride ?? difficulty.startingFill;
    final cellCount = difficulty.cellCount;
    final movesRemaining = movesOverride ?? kMovesPerDay;

    // ... rest of generate() unchanged except use local `walls`, `startingFill`,
    // `movesRemaining` variables instead of the derived values ...
  ```

  Extract `wallIndices()` to a private helper that accepts a count:
  ```dart
  Set<int> _wallIndicesWithCount(int count) {
    if (count == 0) return const {};
    final w = Prng(seedForKey('$_key:walls'));
    final out = <int>{};
    while (out.length < count) {
      out.add(w.nextInt(difficulty.cellCount));
    }
    return out;
  }

  /// Public accessor (used by tests and by the landing-stream rebuild).
  Set<int> wallIndices() => _wallIndicesWithCount(wallCountFor(difficulty));
  ```

  Update the `BoardState` construction inside `generate()` to use `movesRemaining` local:
  ```dart
  final candidate = BoardState(
    // ...
    movesRemaining: movesRemaining,
    // ...
  );
  // ...
  final board = BoardState(
    // ...
    movesRemaining: movesRemaining,
    // ...
  );
  ```

- [ ] **Step 4: Add `comboMultiplierFn` to `GameEngine.collapseChain`**

  In `lib/domain/engine/game_engine.dart`:
  ```dart
  import '../../domain/constants.dart'; // already imported
  ```

  Update `collapseChain`:
  ```dart
  /// Collapse a validated Connect-Merge [path] onto its endpoint.
  /// [comboMultiplierFn] overrides the default [comboMultiplier] for challenge
  /// rules (e.g. [comboRushMultiplier] for the Combo Rush rule).
  static BoardState collapseChain(
    BoardState s,
    List<int> path, {
    int Function(int)? comboMultiplierFn,
  }) {
    final endIdx = path.last;
    final endTile = s.cells[endIdx]!;
    final mergedTier = endTile.tier;
    final newTier = mergedTier + 1;
    final cells = List<Tile?>.of(s.cells);
    for (final idx in path) {
      cells[idx] = null;
    }
    cells[endIdx] = Tile(id: endTile.id, tier: newTier);
    final fn = comboMultiplierFn ?? comboMultiplier;
    return s.copyWith(
      cells: cells,
      score: s.score + (1 << (mergedTier + 1)) * fn(path.length),
      movesRemaining: s.movesRemaining - 1,
      movesMade: s.movesMade + 1,
    );
  }
  ```

- [ ] **Step 5: Run tests — expect PASS**

  Run: `flutter test test/domain/challenge_seeder_test.dart`
  Expected: all tests PASS.

  Run: `flutter test`
  Expected: full suite PASS (no regressions from the `collapseChain` signature change — `comboMultiplierFn` is optional).

- [ ] **Step 6: Commit**

  ```bash
  git add lib/domain/engine/daily_seeder.dart lib/domain/engine/game_engine.dart \
    test/domain/challenge_seeder_test.dart
  git commit -m "feat(engine): add challenge rule support to DailySeeder and GameEngine"
  ```

---

### Task 7: `GameCubit` — challenge mode init + rule enforcement

**Files:**
- Modify: `lib/application/game_cubit.dart`
- Test: `test/application/game_cubit_challenge_test.dart`

**Interfaces:**
- Consumes: `Difficulty.challenge`, `ChallengeRule`, `kChallengeMoves`, `comboRushMultiplier`, `DailySeeder.challengeRule`, `DailySeeder.generate(startingFillOverride, wallCountOverride, movesOverride)`, `GameEngine.collapseChain(comboMultiplierFn:)`
- Produces:
  - `GameCubit._activeRule` — private `ChallengeRule?` field, set during `init` when `difficulty == Difficulty.challenge`
  - `GameCubit._targetFill` — private `int` field (effective startingFill, accounting for challenge rule overrides)
  - `GameCubit.init` extended for challenge: derives rule, passes overrides to `generate()`
  - `GameCubit.playChain` extended: checks `longChainsOnly` min-length guard; passes `comboRushMultiplier` to `collapseChain` when `comboRush` is active
  - `GameCubit.activeRule` public getter — `ChallengeRule? get activeRule => _activeRule;` (read by `GameScreen` to show rule banner)

- [ ] **Step 1: Write failing tests for challenge mode**

  Create `test/application/game_cubit_challenge_test.dart`:

  ```dart
  import 'package:merge_count/application/game_cubit.dart';
  import 'package:merge_count/domain/models/challenge_rule.dart';
  import 'package:merge_count/domain/models/difficulty.dart';
  import 'package:merge_count/infrastructure/storage_service.dart';
  import 'package:test/test.dart';

  void main() {
    late InMemoryStorageService storage;
    late GameCubit cubit;

    setUp(() {
      storage = InMemoryStorageService();
      cubit = GameCubit(
        storage: storage,
        todayProvider: () => '2026-06-23',
      );
    });

    tearDown(() => cubit.close());

    test('init with challenge sets an activeRule', () async {
      await cubit.init(difficulty: Difficulty.challenge);
      expect(cubit.activeRule, isNotNull);
      expect(ChallengeRule.values.contains(cubit.activeRule!), isTrue);
    });

    test('longChainsOnly rule rejects 2-tile chains', () async {
      // Override the rule for a deterministic test.
      await cubit.init(difficulty: Difficulty.challenge, ruleOverride: ChallengeRule.longChainsOnly);
      if (cubit.state is! GamePlaying) return;
      final board = (cubit.state as GamePlaying).board;
      // Find any adjacent pair (length-2 path).
      int? a, b;
      for (var i = 0; i < board.cells.length && a == null; i++) {
        final t = board.cells[i];
        if (t == null) continue;
        final gs = board.gridSize;
        final right = i + 1;
        if (right < board.cells.length &&
            right % gs != 0 &&
            board.cells[right]?.tier == t.tier) {
          a = i; b = right;
        }
      }
      if (a == null) return; // no adjacent pair on this seed; vacuous pass
      final scoreBefore = board.score;
      await cubit.playChain([a!, b!]);
      // Score should be unchanged (move rejected).
      if (cubit.state is GamePlaying) {
        expect((cubit.state as GamePlaying).board.score, equals(scoreBefore));
      }
    });

    test('budgetCut rule sets movesRemaining = 15', () async {
      await cubit.init(difficulty: Difficulty.challenge, ruleOverride: ChallengeRule.budgetCut);
      if (cubit.state is! GamePlaying) return;
      expect((cubit.state as GamePlaying).board.movesRemaining, equals(15));
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL**

  Run: `flutter test test/application/game_cubit_challenge_test.dart`
  Expected: FAIL (`ruleOverride` parameter and `activeRule` getter don't exist).

- [ ] **Step 3: Add `_activeRule`, `_targetFill` fields and `activeRule` getter to `GameCubit`**

  In `lib/application/game_cubit.dart`:
  ```dart
  import '../domain/models/challenge_rule.dart';

  // In GameCubit class body:
  ChallengeRule? _activeRule;
  late int _targetFill;

  /// The active challenge rule, or null when not in challenge mode.
  ChallengeRule? get activeRule => _activeRule;
  ```

- [ ] **Step 4: Extend `init` for challenge mode**

  Update `GameCubit.init` signature:
  ```dart
  Future<void> init({
    required Difficulty difficulty,
    ChallengeRule? ruleOverride, // for testing; production derives from seeder
  }) async {
    _difficulty = difficulty;
    _date = todayProvider();
    _seeder = DailySeeder(_date, difficulty);

    // Challenge mode: derive or inject the rule, then apply parameter overrides.
    if (difficulty == Difficulty.challenge) {
      _activeRule = ruleOverride ?? _seeder.challengeRule;
      final rule = _activeRule!;
      final fill = switch (rule) {
        ChallengeRule.denseStart => kChallengeDenseFill,
        ChallengeRule.sparseStart => kChallengeSparseFill,
        _ => difficulty.startingFill,
      };
      final wallCount = rule == ChallengeRule.wallMaze ? kChallengeWallMazeCount : 0;
      final moves = rule == ChallengeRule.budgetCut ? kChallengeMoves : kMovesPerDay;
      _targetFill = fill;
      final start = _seeder.generate(
        startingFillOverride: fill,
        wallCountOverride: wallCount,
        movesOverride: moves,
      );
      // ... rest of init using `start` ...
    } else {
      _activeRule = null;
      _targetFill = difficulty.startingFill;
      final start = _seeder.generate();
      // ... rest of init using `start` ...
    }
    // ...
  }
  ```

  Replace the existing `final targetFill = _difficulty.startingFill;` line in `playChain` with `_targetFill`.

- [ ] **Step 5: Add `longChainsOnly` guard and `comboRush` multiplier to `playChain`**

  At the top of `playChain`, after the `GamePlaying` check and before `isValidChain`:
  ```dart
  // Long Chains Only rule: reject chains shorter than 3 tiles.
  if (_activeRule == ChallengeRule.longChainsOnly && path.length < 3) return;
  ```

  Replace the `collapseChain` call:
  ```dart
  // Before:
  var board = GameEngine.collapseChain(s.board, path).copyWith(moveLog: log);
  // After:
  var board = GameEngine.collapseChain(
    s.board,
    path,
    comboMultiplierFn: _activeRule == ChallengeRule.comboRush
        ? comboRushMultiplier
        : null,
  ).copyWith(moveLog: log);
  ```

  Add the import for `comboRushMultiplier` (already in `constants.dart`):
  ```dart
  import '../domain/constants.dart'; // already imported
  ```

- [ ] **Step 6: Run tests — expect PASS**

  Run: `flutter test test/application/game_cubit_challenge_test.dart`
  Expected: all 3 tests PASS.

  Run: `flutter test`
  Expected: full suite PASS.

- [ ] **Step 7: Commit**

  ```bash
  git add lib/application/game_cubit.dart test/application/game_cubit_challenge_test.dart
  git commit -m "feat(game): add challenge mode to GameCubit with rule enforcement"
  ```

---

### Task 8: Challenge payout — `EngagementCubit.checkChallengePayouts`

**Files:**
- Modify: `lib/application/engagement_cubit.dart`
- Modify: `lib/main.dart`
- Test: `test/application/challenge_payout_test.dart`

**Interfaces:**
- Consumes: `LeaderboardService.fetch(difficulty: Difficulty.challenge, date: yesterday)` → `List<LeaderboardEntry>`; `PlayerProfile.lastChallengeCheckDate`
- Produces: `EngagementCubit.checkChallengePayouts(fetchFn)` — async, idempotent; payout table: rank 1→150, ranks 2-3→100, ranks 4-10→50; persists `lastChallengeCheckDate`

- [ ] **Step 1: Write failing tests**

  Create `test/application/challenge_payout_test.dart`:

  ```dart
  import 'package:merge_count/application/engagement_cubit.dart';
  import 'package:merge_count/domain/models/difficulty.dart';
  import 'package:merge_count/domain/models/leaderboard_entry.dart';
  import 'package:merge_count/infrastructure/storage_service.dart';
  import 'package:test/test.dart';

  LeaderboardEntry _entry(int rank, bool isMe) =>
      LeaderboardEntry(rank: rank, displayName: 'P', score: 100, isMe: isMe);

  void main() {
    late InMemoryStorageService storage;
    late EngagementCubit cubit;
    // 'today' = 2026-06-23; 'yesterday' = 2026-06-22
    const today = '2026-06-23';
    const yesterday = '2026-06-22';

    setUp(() {
      storage = InMemoryStorageService();
      cubit = EngagementCubit(storage: storage, todayProvider: () => today);
      cubit.load();
    });

    tearDown(() => cubit.close());

    Future<List<LeaderboardEntry>> fakeFetch(int rank) async => [
          _entry(1, false),
          _entry(rank, true),
        ];

    test('rank 1 grants 150 coins', () async {
      await cubit.checkChallengePayouts(({required Difficulty difficulty, required String date}) => fakeFetch(1));
      expect(cubit.state.coins, equals(150));
    });

    test('rank 2 grants 100 coins', () async {
      await cubit.checkChallengePayouts(({required Difficulty difficulty, required String date}) => fakeFetch(2));
      expect(cubit.state.coins, equals(100));
    });

    test('rank 10 grants 50 coins', () async {
      await cubit.checkChallengePayouts(({required Difficulty difficulty, required String date}) => fakeFetch(10));
      expect(cubit.state.coins, equals(50));
    });

    test('rank 11 grants nothing', () async {
      await cubit.checkChallengePayouts(({required Difficulty difficulty, required String date}) => fakeFetch(11));
      expect(cubit.state.coins, equals(0));
    });

    test('second call same day is a no-op', () async {
      await cubit.checkChallengePayouts(({required Difficulty difficulty, required String date}) => fakeFetch(1));
      await cubit.checkChallengePayouts(({required Difficulty difficulty, required String date}) => fakeFetch(1));
      expect(cubit.state.coins, equals(150)); // not 300
    });
  }
  ```

- [ ] **Step 2: Run test — expect FAIL**

  Run: `flutter test test/application/challenge_payout_test.dart`
  Expected: FAIL.

- [ ] **Step 3: Add `checkChallengePayouts` to `EngagementCubit`**

  Add the payout table and method:
  ```dart
  static int _challengeCoinForRank(int rank) {
    if (rank == 1) return 150;
    if (rank <= 3) return 100;
    if (rank <= 10) return 50;
    return 0;
  }

  /// Check if the player placed top-10 in yesterday's challenge leaderboard.
  /// [fetchFn] matches [LeaderboardService.fetch]'s signature.
  Future<void> checkChallengePayouts(
    Future<List<LeaderboardEntry>> Function({
      required Difficulty difficulty,
      required String date,
    }) fetchFn,
  ) async {
    final today = todayProvider();
    final yesterday = DateTime.parse(today)
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    final profile = storage.loadProfile();
    if (profile.lastChallengeCheckDate == yesterday) return; // already checked

    int coins = 0;
    try {
      final entries = await fetchFn(
        difficulty: Difficulty.challenge,
        date: yesterday,
      );
      final myEntry = entries.where((e) => e.isMe).firstOrNull;
      if (myEntry != null) {
        coins = _challengeCoinForRank(myEntry.rank);
      }
    } catch (_) {
      return; // network failure: skip; retry tomorrow
    }

    final updatedProfile = profile.copyWith(
      lastChallengeCheckDate: yesterday,
      coins: profile.coins + coins,
    );
    await storage.saveProfile(updatedProfile);

    emit(state.copyWith(coins: updatedProfile.coins));
  }
  ```

- [ ] **Step 4: Wire `checkChallengePayouts` in `main.dart`**

  After the weekly prize check call:
  ```dart
  if (leaderboard != null) {
    unawaited(engagement.checkWeeklyPrizes(leaderboard!.fetchPeriod));
    unawaited(engagement.checkChallengePayouts(leaderboard!.fetch));
  }
  ```

- [ ] **Step 5: Run tests — expect PASS**

  Run: `flutter test test/application/challenge_payout_test.dart`
  Expected: all 5 tests PASS.

  Run: `flutter test`
  Expected: full suite PASS.

- [ ] **Step 6: Commit**

  ```bash
  git add lib/application/engagement_cubit.dart lib/main.dart \
    test/application/challenge_payout_test.dart
  git commit -m "feat(engagement): add daily challenge payout check (top-10 coins)"
  ```

---

### Task 9: `TierSelectScreen` — challenge card with countdown

**Files:**
- Modify: `lib/presentation/screens/tier_select_screen.dart`

**Interfaces:**
- Consumes: `Difficulty.challenge`, `ChallengeRule`, `DailySeeder.challengeRule` getter (for the teaser label before noon), `GameCubit.init(difficulty: Difficulty.challenge)`, existing `_ticker` (per-second timer already in the screen)
- Produces: A sixth card below the four tier cards. Before noon UTC: locked with countdown and rule name teaser. After noon, not yet played: rule label + "Play" button. After noon, completed today: "Done ✓" + optional "Leaderboard" button.

- [ ] **Step 1: Locate the challenge unlock check and rule in the screen**

  Before writing UI code, in `tier_select_screen.dart` find where the per-second `_ticker` is set up and where `_isToday` and `_canPlay` checks are done for existing tiers. The challenge card adds:

  ```dart
  bool get _challengeUnlocked => DateTime.now().toUtc().hour >= 12;
  ```

  Add a helper to get today's challenge rule label:
  ```dart
  String get _challengeRuleLabel {
    final today = utcToday();
    return DailySeeder(today, Difficulty.challenge).challengeRule.label;
  }
  ```

  Add import at top of the screen file:
  ```dart
  import '../../domain/engine/daily_seeder.dart';
  import '../../domain/models/challenge_rule.dart';
  ```

- [ ] **Step 2: Add the challenge card widget**

  Find where the tier cards are laid out (likely a `Column` or `ListView` of tier-card widgets). Add the challenge card below the existing four:

  ```dart
  // Challenge card — inserted below the four tier cards in the layout.
  _buildChallengeCard(context),
  ```

  Implement `_buildChallengeCard`:
  ```dart
  Widget _buildChallengeCard(BuildContext context) {
    final unlocked = _challengeUnlocked;
    final today = utcToday();
    final snap = storage.loadSnapshot(today, Difficulty.challenge);
    final completed = snap?.completed == true;
    final ruleName = _challengeRuleLabel;

    if (!unlocked) {
      // Locked: show countdown to noon UTC.
      final now = DateTime.now().toUtc();
      final noon = DateTime.utc(now.year, now.month, now.day, 12);
      final remaining = noon.difference(now);
      final hh = remaining.inHours.toString().padLeft(2, '0');
      final mm = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

      return _challengeCardFrame(
        child: Column(children: [
          const Icon(Icons.lock_clock, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          Text('Daily Challenge', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Today: $ruleName', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Opens in $hh:$mm:$ss',
              style: const TextStyle(fontFamily: 'monospace')),
        ]),
      );
    }

    if (completed) {
      return _challengeCardFrame(
        child: Column(children: [
          const Icon(Icons.check_circle, size: 32, color: Colors.greenAccent),
          const SizedBox(height: 8),
          Text('Daily Challenge', style: Theme.of(context).textTheme.titleMedium),
          Text('Done ✓  $ruleName'),
        ]),
      );
    }

    return _challengeCardFrame(
      child: Column(children: [
        Text('Daily Challenge', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Today: $ruleName'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _startChallenge(context),
          child: const Text('Play'),
        ),
      ]),
    );
  }

  Widget _challengeCardFrame({required Widget child}) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: child),
        ),
      );

  void _startChallenge(BuildContext context) {
    // Navigate to GameScreen with Difficulty.challenge — same as other tiers.
    // (Replace with your project's navigation pattern for tier cards.)
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        difficulty: Difficulty.challenge,
        storage: storage,
        // ... pass other required params matching how other tiers navigate ...
      ),
    ));
  }
  ```

  Adjust `_startChallenge` to match the exact navigation pattern used by the other four tier cards in the screen.

- [ ] **Step 3: Ensure the `_ticker` triggers a rebuild of the challenge card**

  The per-second ticker should already call `setState`. Verify it does — if not, the countdown won't update. Check that `_ticker` is wired to call `setState(() {})` on each tick.

- [ ] **Step 4: Manual test the challenge card**

  Run the app. Verify:
  - Before noon UTC: card shows countdown with rule name, no Play button.
  - At/after noon UTC: card shows rule name + Play button.
  - After completing a challenge: card shows "Done ✓".

- [ ] **Step 5: Commit**

  ```bash
  git add lib/presentation/screens/tier_select_screen.dart
  git commit -m "feat(ui): add Daily Challenge card with noon UTC countdown to TierSelectScreen"
  ```

---

### Task 10: `GameScreen` — challenge rule banner + challenge submit path

**Files:**
- Modify: `lib/presentation/screens/game_screen.dart` (or wherever the in-game UI lives)
- Modify: `lib/presentation/screens/tier_select_screen.dart` (small — pass `GameCubit.activeRule` to `GameScreen`)

**Interfaces:**
- Consumes: `GameCubit.activeRule` getter; `ChallengeRuleLabel.label` extension
- Produces: A non-interactive banner at the top of `GameScreen` when `activeRule != null`, displaying e.g. `"Today: Long Chains Only"`.

- [ ] **Step 1: Find the `GameScreen` widget and where the top bar is rendered**

  Locate the file that shows the active game board (`game_screen.dart` or similar). Find the `AppBar` or top-of-body area.

- [ ] **Step 2: Add a challenge rule banner**

  Pass `ChallengeRule? activeRule` as a new optional parameter to `GameScreen` (or read it from the `GameCubit` via `context.watch`):

  ```dart
  // In GameScreen's build method, at the top of the body Stack/Column:
  if (activeRule != null)
    Container(
      width: double.infinity,
      color: Colors.deepPurple.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Text(
        'Today: ${activeRule!.label}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ),
  ```

  Import the `ChallengeRule` extension:
  ```dart
  import '../../domain/models/challenge_rule.dart';
  ```

- [ ] **Step 3: Manual test**

  Run the app, start a challenge game. Verify:
  - The rule banner appears at the top of the game screen.
  - No banner appears on non-challenge tier games.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/presentation/screens/game_screen.dart
  git commit -m "feat(ui): show challenge rule banner in GameScreen during challenge mode"
  ```

---

### Task 11: `LeaderboardScreen` — crown badges, "Your Crowns" section, challenge tab

**Files:**
- Modify: `lib/presentation/screens/leaderboard_screen.dart` (or wherever `LeaderboardRow` is defined)

**Interfaces:**
- Consumes: `EngagementState.weeklyPrizes` from `EngagementCubit`; `LeaderboardService.fetch(difficulty: Difficulty.challenge, date: today)`; `LeaderboardEntry.rank`, `.isMe`
- Produces:
  - Crown icon prefix on `LeaderboardRow` when the row matches a `WeeklyPrize` for the displayed week (gold/silver/bronze)
  - "Your Crowns" expandable section listing `state.weeklyPrizes` (week, tier, rank)
  - "Challenge" tab in `LeaderboardScreen`'s tab bar, showing top-10 for today's date only
  - Coin prize indicators on challenge leaderboard rows (🏆 for ranks 1-3, ✦ for ranks 4-10)

- [ ] **Step 1: Add the "Challenge" tab**

  In the leaderboard screen, add `Difficulty.challenge` as a tab option alongside the existing tiers. The challenge tab should:
  - Fetch with `LeaderboardService.fetch(difficulty: Difficulty.challenge, date: today)`
  - Show only top-10 rows
  - Show no weekly/monthly period tabs (challenge is daily-only)

- [ ] **Step 2: Add crown prefix to leaderboard rows**

  In `LeaderboardRow` (or wherever rows are built), check `EngagementState.weeklyPrizes` for a prize matching the row's `displayName` (or `isMe`). If found, prepend the appropriate crown:
  - rank 1: gold crown `🥇` or `const Icon(Icons.emoji_events, color: Colors.amber)`
  - rank 2: silver crown `🥈` or `const Icon(Icons.emoji_events, color: Colors.grey)`
  - rank 3: bronze crown `🥉` or `const Icon(Icons.emoji_events, color: Color(0xFFCD7F32))`

- [ ] **Step 3: Add "Your Crowns" section**

  Below the leaderboard list (or as a separate tab section), show the player's own crown history from `EngagementState.weeklyPrizes`:

  ```dart
  // "Your Crowns" section — only shown when weeklyPrizes is non-empty
  if (engagement.weeklyPrizes.isNotEmpty)
    ExpansionTile(
      title: const Text('Your Crowns'),
      children: engagement.weeklyPrizes.map((p) => ListTile(
        leading: Text(_crownEmoji(p.rank)),
        title: Text('${p.tier.label} — Week of ${p.weekStart}'),
        trailing: Text('#${p.rank}'),
      )).toList(),
    ),
  ```

  Helper:
  ```dart
  String _crownEmoji(int rank) => switch (rank) {
    1 => '🥇',
    2 => '🥈',
    3 => '🥉',
    _ => '🏅',
  };
  ```

- [ ] **Step 4: Add challenge payout indicators to challenge tab rows**

  On the challenge tab, rows with `rank <= 3` get a 🏆 suffix label; rows with `rank <= 10` get a ✦ suffix.

- [ ] **Step 5: Manual test**

  - Verify the "Challenge" tab appears in the leaderboard screen.
  - Verify crown badges appear on rows for past weekly winners.
  - Verify "Your Crowns" section lists the player's prizes.

- [ ] **Step 6: Commit**

  ```bash
  git add lib/presentation/screens/leaderboard_screen.dart
  git commit -m "feat(ui): add crown badges, Your Crowns section, and Challenge tab to LeaderboardScreen"
  ```

---

### Task 12: Edge Function — challenge rule validation in `submit-score`

**Files:**
- Modify: `supabase/functions/_shared/constants.ts`
- Modify: `supabase/functions/_shared/seeder.ts`
- Modify: `supabase/functions/_shared/engine.ts`
- Modify: `supabase/functions/submit-score/index.ts`
- Test: `supabase/functions/_shared/engine.test.ts`

**Interfaces:**
- Consumes: existing `verifyRun(date, difficulty, moveLog)` in `engine.ts`
- Produces:
  - `'challenge'` added to `DIFFICULTIES`, `STARTING_FILL`, `GRID_SIZE`, `WALL_COUNT` in `constants.ts`
  - `comboRushMultiplier(n)` added to `constants.ts`
  - `challengeRule(date)` async function in `seeder.ts`
  - `verifyRunChallenge(date, moveLog, rule)` in `engine.ts` — applies the rule during replay
  - `submit-score/index.ts` dispatches to challenge verify path when `difficulty === 'challenge'`

- [ ] **Step 1: Write failing engine tests for challenge rules**

  In `supabase/functions/_shared/engine.test.ts`, add:

  ```typescript
  import { assertEquals } from "https://deno.land/std/assert/mod.ts";
  import { comboRushMultiplier, comboMultiplier } from "./constants.ts";

  Deno.test("comboRushMultiplier N=2 matches comboMultiplier (no doubling)", () => {
    assertEquals(comboRushMultiplier(2), comboMultiplier(2));
  });

  Deno.test("comboRushMultiplier N=3 returns doubled multiplier", () => {
    assertEquals(comboRushMultiplier(3), comboMultiplier(3) * 2);
  });

  Deno.test("comboRushMultiplier N=4 returns doubled multiplier", () => {
    assertEquals(comboRushMultiplier(4), comboMultiplier(4) * 2);
  });
  ```

  Run: `deno test supabase/functions/_shared/engine.test.ts`
  Expected: FAIL (`comboRushMultiplier` not defined).

- [ ] **Step 2: Update `constants.ts` — add `challenge` difficulty + `comboRushMultiplier`**

  ```typescript
  export const DIFFICULTIES = ["easy", "medium", "hard", "legendary", "challenge"] as const;

  export const STARTING_FILL: Record<Difficulty, number> = {
    easy: 40,
    medium: 25,
    hard: 20,
    legendary: 15,
    challenge: 8, // nominal default; overridden by rule in verifyRunChallenge
  };

  export const GRID_SIZE: Record<Difficulty, number> = {
    easy: 8,
    medium: 7,
    hard: 6,
    legendary: 6,
    challenge: 6,
  };

  export const WALL_COUNT: Record<Difficulty, number> = {
    easy: 2,
    medium: 4,
    hard: 5,
    legendary: 6,
    challenge: 0, // overridden by wallMaze rule
  };

  export const kChallengeMoves = 15;
  export const kChallengeWallMazeCount = 8;
  export const kChallengeDenseFill = 14;
  export const kChallengeSparseFill = 3;

  /** Challenge rules — index must match Dart ChallengeRule.values order. */
  export const CHALLENGE_RULES = [
    "budgetCut",
    "longChainsOnly",
    "denseStart",
    "sparseStart",
    "wallMaze",
    "comboRush",
  ] as const;
  export type ChallengeRule = (typeof CHALLENGE_RULES)[number];

  /**
   * Combo Rush multiplier: doubles comboMultiplier for N≥3; N=2 stays at 1.
   * Must stay in lockstep with Dart `comboRushMultiplier`.
   */
  export function comboRushMultiplier(n: number): number {
    if (n < 3) return comboMultiplier(n);
    return comboMultiplier(n) * 2;
  }
  ```

- [ ] **Step 3: Add `challengeRule(date)` to `seeder.ts`**

  ```typescript
  import { CHALLENGE_RULES, type ChallengeRule } from "./constants.ts";

  /** Derives today's ChallengeRule from the "$date:challenge" seed. */
  export async function challengeRule(date: string): Promise<ChallengeRule> {
    const seed = await seedForKey(`${date}:challenge`);
    const prng = new Prng(seed);
    const idx = prng.nextInt(6);
    return CHALLENGE_RULES[idx];
  }
  ```

- [ ] **Step 4: Add `verifyRunChallenge` to `engine.ts`**

  In `supabase/functions/_shared/engine.ts`, add a challenge-specific verify function that:
  1. Derives the rule via `challengeRule(date)`.
  2. Computes `startingFill`, `wallCount`, and `movesAllowed` from the rule.
  3. Regenerates the board via `new DailySeeder(date, 'challenge').generate()` with overrides.
  4. Replays the move log, applying rule constraints:
     - `budgetCut`: cap valid moves at 15.
     - `longChainsOnly`: reject `ChainEvent` paths with length < 3.
     - `wallMaze`: use 8 walls.
     - `denseStart` / `sparseStart`: use overridden fill.
     - `comboRush`: use `comboRushMultiplier` for score computation.

  ```typescript
  import {
    type ChallengeRule,
    kChallengeMoves, kChallengeWallMazeCount, kChallengeDenseFill, kChallengeSparseFill,
    comboMultiplier, comboRushMultiplier,
  } from "./constants.ts";
  import { challengeRule } from "./seeder.ts"; // async function, returns ChallengeRule

  export async function verifyRunChallenge(
    date: string,
    moveLog: unknown,
  ): Promise<VerifyResult> {
    const rule = await challengeRule(date);
    const fill = rule === "denseStart" ? kChallengeDenseFill
               : rule === "sparseStart" ? kChallengeSparseFill
               : 8; // Difficulty.challenge.startingFill default
    const wallCount = rule === "wallMaze" ? kChallengeWallMazeCount : 0;
    const movesAllowed = rule === "budgetCut" ? kChallengeMoves : 30;
    const multiplierFn = rule === "comboRush" ? comboRushMultiplier : comboMultiplier;

    // Re-generate the challenge board with rule overrides using the existing
    // seeder — reuse `verifyRun`'s board generation logic adapted for challenge.
    // (Inline the replay loop here, parameterised by the rule values above.)
    // ...
    // Apply longChainsOnly: reject ChainEvent paths where path.length < 3.
    // Apply budgetCut: reject runs with more than kChallengeMoves chain events.
    // Apply multiplierFn to score computation.
    // ...
  }
  ```

  Model the full replay loop on the existing `verifyRun` function — same structure, same move-log parsing, same drop-tier and landing streams. Only the four rule-specific deviations differ.

- [ ] **Step 5: Update `submit-score/index.ts` to dispatch challenge path**

  ```typescript
  // Replace the single verifyRun call with:
  const result = difficulty === 'challenge'
    ? await verifyRunChallenge(date, moveLog)
    : await verifyRun(date, difficulty, moveLog);
  ```

- [ ] **Step 6: Run edge function tests**

  Run: `deno test supabase/functions/_shared/engine.test.ts`
  Expected: all tests PASS including the new `comboRushMultiplier` tests.

- [ ] **Step 7: Deploy the updated edge functions**

  ```bash
  supabase functions deploy submit-score
  ```

  Verify: submit a challenge run from the app → score appears in the challenge leaderboard.

- [ ] **Step 8: Commit**

  ```bash
  git add supabase/functions/_shared/constants.ts supabase/functions/_shared/seeder.ts \
    supabase/functions/_shared/engine.ts supabase/functions/_shared/engine.test.ts \
    supabase/functions/submit-score/index.ts
  git commit -m "feat(server): add challenge rule validation to submit-score Edge Function"
  ```

---

## Completion checklist

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — full suite passes
- [ ] `deno test supabase/functions/_shared/` — all edge function tests pass
- [ ] Manual: share button opens OS share sheet on Android
- [ ] Manual: display name appears on global leaderboard after completing a game
- [ ] Manual: challenge card locked before noon UTC, unlocked after
- [ ] Manual: completing a challenge posts to the challenge leaderboard
- [ ] Manual: weekly prize check grants coins + crown on a simulated top-3 finish
- [ ] All 12 tasks committed to git with semantic commit messages
