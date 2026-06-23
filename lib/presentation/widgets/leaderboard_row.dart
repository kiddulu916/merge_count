import 'package:flutter/material.dart';

import '../../domain/models/leaderboard_entry.dart';

/// A single leaderboard row: rank, display name, score, and a "You" highlight
/// for the caller's own row. Shared by the global ([LeaderboardScreen]) and
/// friends ([FriendsLeaderboard]) boards so both render identically.
class LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  /// Optional crown emoji prefix shown before the rank on the player's own row
  /// (e.g. '🥇', '🥈', '🥉') when the player has a matching weekly prize.
  final String? crownEmoji;

  /// Optional prize-indicator suffix shown after the score on challenge board
  /// rows (e.g. '🏆' for ranks 1-3, '✦' for ranks 4-10).
  final String? prizeSuffix;

  const LeaderboardRow({
    super.key,
    required this.entry,
    this.crownEmoji,
    this.prizeSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('lb-row-${entry.rank}'),
      color: entry.isMe
          ? Colors.deepPurpleAccent.withValues(alpha: 0.18)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (crownEmoji != null) ...[
            Text(crownEmoji!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
          ],
          SizedBox(
            width: 36,
            child: Text('#${entry.rank}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: entry.isMe ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text('${entry.score}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          if (prizeSuffix != null) ...[
            const SizedBox(width: 6),
            Text(prizeSuffix!,
                style: const TextStyle(color: Colors.amber, fontSize: 14)),
          ],
          if (entry.isMe) ...[
            const SizedBox(width: 8),
            const Text('You',
                style: TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
