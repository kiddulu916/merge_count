import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/application/game_cubit.dart';
import 'package:merge_loop/application/game_state.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/engine/daily_seeder.dart';
import 'package:merge_loop/domain/engine/game_engine.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/infrastructure/storage_service.dart';

void main() {
  late InMemoryStorageService storage;
  GameCubit make(String date) =>
      GameCubit(storage: storage, todayProvider: () => date);

  setUp(() => storage = InMemoryStorageService());

  test('init on a fresh day seeds a playing board and persists it', () async {
    final c = make('2026-06-06');
    await c.init();
    expect(c.state, isA<GamePlaying>());
    final board = (c.state as GamePlaying).board;
    expect(board.filledCount, kStartingFill);
    expect(storage.loadSnapshot()!.date, '2026-06-06');
  });

  test('init routes to score screen when today already completed', () async {
    final seeded = const DailySeeder('2026-06-06').generate().board.copyWith(
        status: GameStatus.outOfMoves, movesRemaining: 0);
    await storage.saveSnapshot(
        GameSnapshot(date: '2026-06-06', board: seeded, completed: true));

    final c = make('2026-06-06');
    await c.init();
    expect(c.state, isA<GameOverShowScore>());
  });

  test('a legal merge updates score, spends a move, and triggers one drop', () async {
    final c = make('2026-06-06');
    await c.init();
    final board = (c.state as GamePlaying).board;

    final pair = _findMergePair(board);
    await c.merge(fromIndex: pair.$1, toIndex: pair.$2);

    final after = (c.state as GamePlaying).board;
    expect(after.movesMade, 1);
    expect(after.movesRemaining, kMovesPerDay - 1);
    expect(after.dropIndex, 1);
    expect(after.score, greaterThan(0));
    expect(after.filledCount, board.filledCount);
  });

  test('grantAdReward adds moves, increments continues, resumes play', () async {
    final start = const DailySeeder('2026-06-06').generate().board;
    final outOfMoves = start.copyWith(movesRemaining: 0, status: GameStatus.outOfMoves);
    await storage.saveSnapshot(
        GameSnapshot(date: '2026-06-06', board: outOfMoves, completed: true));

    final c = make('2026-06-06');
    await c.init();
    expect(c.state, isA<GameOverShowScore>());
    expect(c.canOfferAd, GameEngine.hasMergeAvailable(outOfMoves));

    await c.grantAdReward();
    final board = (c.state as GamePlaying).board;
    expect(board.movesRemaining, kAdMoveReward);
    expect(board.adContinuesUsed, 1);
    expect(board.status, GameStatus.playing);
  });
}

(int, int) _findMergePair(BoardState b) {
  final byTier = <int, int>{};
  for (var i = 0; i < b.cells.length; i++) {
    final t = b.cells[i];
    if (t == null || t.tier >= kMaxTier) continue;
    if (byTier.containsKey(t.tier)) return (byTier[t.tier]!, i);
    byTier[t.tier] = i;
  }
  throw StateError('seeded board unexpectedly has no merge pair');
}
