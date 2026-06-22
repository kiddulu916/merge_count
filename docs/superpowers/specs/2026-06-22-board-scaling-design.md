# Board Scaling + Deadlock Fix — Design Spec

**Date:** 2026-06-22
**Branch:** feat/connect-merge-redesign
**Status:** Approved — ready for implementation

---

## Problem

Under the Connect-Merge adjacency rule, the board deadlocks after 1–2 moves on
Medium/Hard/Legendary in 50–98% of daily seeds. Two compounding causes:

1. **Boards are too sparse.** The old fills (4–10 tiles on 25 cells) were tuned
   for the legacy "any two equal tiles anywhere" rule. Under the new adjacency
   rule, sparse boards rarely produce orthogonally-adjacent same-tier pairs.

2. **Refill has no deadlock guarantee.** `GameCubit.playChain` fills to
   `startingFill` and stops. If the newly dropped tiles don't land adjacent to a
   matching tile, the board is immediately deadlocked — and `evaluateStatus`
   ends the run.

A simulation (200 seeds × 4 difficulties, greedy-optimal play) confirmed:

| Difficulty | Median merges before death | Dead in ≤ 2 merges |
|---|---|---|
| Easy | 5 | 20% |
| Medium | 2 | 56% |
| Hard | 2 | 70% |
| Legendary | 1 | 98% |

---

## Solution

Two changes in combination:

1. **Variable grid size per difficulty** — larger boards at easier tiers give
   more room for chains. Legendary stays "only slightly bigger than now" (6×6 vs
   current 5×5).

2. **Refill deadlock guarantee** — after every chain collapse, the refill loop
   continues dropping until *both* `filledCount >= startingFill` **and**
   `hasMergeAvailable` are true, or the board is completely full. This mirrors
   the seeder's born-deadlock re-roll guarantee at start-of-day.

---

## Constants

### Per-difficulty board parameters

| Difficulty | Grid | Total cells | Fill | Walls | Available cells |
|---|---|---|---|---|---|
| Easy | 8×8 | 64 | 40 | 2 | 62 |
| Medium | 7×7 | 49 | 25 | 4 | 45 |
| Hard | 6×6 | 36 | 20 | 5 | 31 |
| Legendary | 6×6 | 36 | 15 | 6 | 30 |

These replace the old values (fill: 10/8/6/4, grid: 5×5 all tiers, walls: 0/2/3/4).

### Snapshot version

`kSnapshotVersion` bumps from `2` → `3`. Old snapshots are discarded on load
(the daily board geometry changed; old saves are incompatible). Players start a
fresh game when they update.

---

## Architecture

### `gridSize` propagation

`gridSize` moves from the global `kGridSize = 5` constant to a **field on the
`Difficulty` enum**. It then flows into `BoardState` as an optional field
(default `5`) so all existing test board helpers compile without changes.

```dart
// difficulty.dart
enum Difficulty {
  easy(gridSize: 8, startingFill: 40, label: 'Easy'),
  medium(gridSize: 7, startingFill: 25, label: 'Medium'),
  hard(gridSize: 6, startingFill: 20, label: 'Hard'),
  legendary(gridSize: 6, startingFill: 15, label: 'Legendary');

  final int gridSize;
  final int startingFill;
  final String label;
  int get cellCount => gridSize * gridSize;
}

// board_state.dart — new optional field, default 5
final int gridSize; // default: 5 (legacy/test boards)
```

All engine geometry methods (`hasMergeAvailable`, `isValidChain`,
`areOrthogonallyAdjacent`) read `board.gridSize` at runtime. The
`areOrthogonallyAdjacent` static method gains a required `int gridSize`
parameter (breaking change — 4 test call sites updated).

`kGridSize = 5` and `kCellCount = 25` remain in `constants.dart` as
"legacy / test use only" — existing test helpers that construct 5×5 boards
continue compiling unchanged.

### Wall counts

`wallCountFor(Difficulty)` in `constants.dart` (Dart) and `WALL_COUNT` record
in `constants.ts` (TypeScript) updated to new values.

---

## Refill guarantee algorithm

### Current (broken)

```dart
while (board.filledCount < targetFill && board.emptyIndices.isNotEmpty) {
  board = GameEngine.applyDrop(board, tier, landing, ...);
}
```

### New (fixed)

```dart
// Fill to targetFill AND guarantee at least one adjacent merge exists.
// Stop early only if board is completely full (true deadlock → evaluateStatus).
while (board.emptyIndices.isNotEmpty) {
  final needsFill = board.filledCount < targetFill;
  final needsMerge = !GameEngine.hasMergeAvailable(board);
  if (!needsFill && !needsMerge) break;
  board = GameEngine.applyDrop(board, tier, landing, ...);
}
```

This loop is **deterministic** — the same `Prng` streams are advanced in the
same order on both client (Dart) and server (TypeScript). The server's
`verifyRun` loop must be updated identically, or legitimate runs will be
rejected.

---

## Server parity (TypeScript)

The TypeScript server (`supabase/functions/_shared/`) must mirror every
Dart change exactly. The server is the authoritative replay verifier — any
divergence causes valid client runs to be rejected.

Changes required in TypeScript:

| File | Change |
|---|---|
| `constants.ts` | Add `GRID_SIZE` record, update `STARTING_FILL` and `WALL_COUNT` |
| `engine.ts` | Add `gridSize` to `BoardState` interface; update `areOrthogonallyAdjacent`, `isValidChain`, `hasMergeAvailable` to use `board.gridSize`; update refill loop in `verifyRun` |
| `seeder.ts` | Use `GRID_SIZE[difficulty]` and `cellCount` in `generate()`, `wallIndices()`, `hasAdjacentSameTier()` |

---

## Files changed

### Dart

| File | Change |
|---|---|
| `lib/domain/models/difficulty.dart` | Add `gridSize`, `cellCount`; update fill values |
| `lib/domain/models/board_state.dart` | Add optional `gridSize` field (default 5); update `copyWith`, `toJson`, `fromJson` |
| `lib/domain/constants.dart` | Bump `kSnapshotVersion` to 3; update `wallCountFor`; comment `kGridSize`/`kCellCount` as legacy |
| `lib/domain/engine/game_engine.dart` | `areOrthogonallyAdjacent` gets `int gridSize` param; `hasMergeAvailable` and `isValidChain` use `s.gridSize` |
| `lib/domain/engine/daily_seeder.dart` | Use `difficulty.gridSize` / `difficulty.cellCount` in placement and wall sampling |
| `lib/application/game_cubit.dart` | New refill loop with deadlock guarantee |
| `lib/presentation/widgets/board_widget.dart` | Replace `kGridSize`/`kCellCount` with `widget.board.gridSize` / `widget.board.cells.length` |
| `lib/presentation/widgets/share_card.dart` | Replace `kGridSize`/`kCellCount` with `board.gridSize` / `board.cells.length` |
| `lib/domain/engine/share_grid_builder.dart` | Replace `kGridSize` with `board.gridSize` in emoji-grid text builder |

### TypeScript server

| File | Change |
|---|---|
| `supabase/functions/_shared/constants.ts` | Add `GRID_SIZE`; update `STARTING_FILL`, `WALL_COUNT` |
| `supabase/functions/_shared/engine.ts` | Add `gridSize` to `BoardState`; update geometry functions; update `verifyRun` refill loop |
| `supabase/functions/_shared/seeder.ts` | Use `GRID_SIZE[difficulty]` in `generate()`, `wallIndices()`, `hasAdjacentSameTier()` |

### Tests updated

| File | Change |
|---|---|
| `test/domain/models/difficulty_test.dart` | Update startingFill expectations (40/25/20/15); add gridSize assertions |
| `test/domain/engine/game_engine_test.dart` | Add `gridSize` (5) as 3rd arg to all `areOrthogonallyAdjacent` calls |
| `test/domain/constants_test.dart` | `kGridSize` / `kCellCount` assertions stay (still 5 / 25) |
| `test/presentation/board_widget_test.dart` | Pass `gridSize` to board helpers where cell-size math is tested |

### Test file created (keep)

`test/domain/engine/deadlock_repro_test.dart` — the simulation harness that
confirmed the bug. Keep it; update `longestChain` to use `board.gridSize`.

---

## Out of scope

- Changes to `kMovesPerDay`, `dropCap`, ad-continue logic, scoring, or the
  objective system.
- UI layout changes beyond the board widget (the board widget auto-scales to
  its container via `LayoutBuilder`; no screen layout changes needed).
- Leaderboard season bump (scores remain comparable; only board geometry
  changed, not scoring rules).
