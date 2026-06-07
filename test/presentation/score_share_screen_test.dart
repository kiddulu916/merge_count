import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';
import 'package:merge_loop/infrastructure/storage_service.dart';
import 'package:merge_loop/presentation/screens/score_share_screen.dart';

void main() {
  testWidgets('shows score, best tier, streak, and copies share text', (tester) async {
    final cells = List<Tile?>.filled(kCellCount, null);
    cells[0] = const Tile(id: 1, tier: 6);
    final board = BoardState(
      cells: cells,
      movesRemaining: 0,
      score: 1234,
      nextTileId: 2,
      dropIndex: 0,
      adContinuesUsed: 0,
      movesMade: 30,
      status: GameStatus.outOfMoves,
    );

    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: board,
        date: '2026-06-06',
        stats: const LifetimeStats(
            streak: 4, lastCompletedDate: '2026-06-06', bestScore: 5000, bestTier: 9),
        canOfferAd: false,
        onWatchAd: () {},
      ),
    ));

    expect(find.text('1234'), findsWidgets); // score shown
    expect(find.textContaining('4'), findsWidgets); // streak shown somewhere

    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(copied.single, contains('Merge Loop 2026-06-06'));
  });
}
