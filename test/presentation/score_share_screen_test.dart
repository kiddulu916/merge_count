import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';
import 'package:merge_loop/infrastructure/storage_service.dart';
import 'package:merge_loop/presentation/screens/score_share_screen.dart';

BoardState _board() {
  final cells = List<Tile?>.filled(kCellCount, null);
  cells[0] = const Tile(id: 1, tier: 6);
  return BoardState(
    cells: cells,
    movesRemaining: 0,
    score: 1234,
    nextTileId: 2,
    dropIndex: 0,
    adContinuesUsed: 0,
    movesMade: 30,
    status: GameStatus.outOfMoves,
  );
}

const _stats = LifetimeStats(
    streak: 4, lastCompletedDate: '2026-06-06', bestScore: 5000, bestTier: 9);

void main() {
  testWidgets('shows the core stats', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
      ),
    ));
    expect(find.text('1234'), findsWidgets); // score
    expect(find.textContaining('4'), findsWidgets); // streak
  });

  testWidgets('Main Menu button invokes onMainMenu', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
        onMainMenu: () => tapped++,
      ),
    ));

    expect(find.byKey(const Key('main-menu-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('main-menu-button')));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('Main Menu button is hidden when no callback given',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
      ),
    ));
    expect(find.byKey(const Key('main-menu-button')), findsNothing);
  });
}
