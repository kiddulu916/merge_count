import '../domain/models/board_state.dart';
import '../infrastructure/storage_service.dart';

sealed class GameState {
  const GameState();
}

class GameInitial extends GameState {
  const GameInitial();
}

class GamePlaying extends GameState {
  final BoardState board;
  const GamePlaying({required this.board});
}

class GameOverShowScore extends GameState {
  final BoardState board;
  final String date;
  final LifetimeStats stats;
  const GameOverShowScore({
    required this.board,
    required this.date,
    required this.stats,
  });
}

/// Transient state emitted immediately before resuming play after a rewarded
/// ad, so the UI can flash feedback. The cubit emits GamePlaying right after.
class GameAdRewardGranted extends GameState {
  final BoardState board;
  const GameAdRewardGranted({required this.board});
}
