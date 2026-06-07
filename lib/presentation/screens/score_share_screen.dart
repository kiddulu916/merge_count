import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/engine/share_grid_builder.dart';
import '../../domain/models/board_state.dart';
import '../../infrastructure/storage_service.dart';

/// Offline daily result: the player's own score/tier/moves plus local personal
/// stats. The emoji share is the (offline) comparison mechanism.
class ScoreShareScreen extends StatelessWidget {
  final BoardState board;
  final String date;
  final LifetimeStats stats;
  final bool canOfferAd;
  final VoidCallback onWatchAd;

  const ScoreShareScreen({
    super.key,
    required this.board,
    required this.date,
    required this.stats,
    required this.canOfferAd,
    required this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Daily Result',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              _bigStat('SCORE', '${board.score}'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _smallStat('BEST TILE', '${1 << board.highestTier}'),
                  _smallStat('MOVES', '${board.movesMade}'),
                  _smallStat('STREAK', '${stats.streak}'),
                ],
              ),
              const SizedBox(height: 8),
              _smallStat('BEST EVER', '${stats.bestScore}'),
              const SizedBox(height: 24),
              if (canOfferAd)
                FilledButton.tonal(
                  onPressed: onWatchAd,
                  child: const Text('Watch ad for more moves'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _share(context),
                child: const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final text = ShareGridBuilder.build(date: date, board: board);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result copied to clipboard!')),
      );
    }
  }

  Widget _bigStat(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, letterSpacing: 2)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900)),
        ],
      );

  Widget _smallStat(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ],
      );
}
