import 'difficulty.dart';

/// A read-only view of everything an achievement predicate can inspect. Kept
/// plugin-free and immutable so unlock predicates stay pure and unit-testable.
///
/// `dailyActiveStreak` is the headline "any tier today" streak; per-tier streaks
/// live in [perTierStreak]. `bestTierByDifficulty` is the highest tier reached in
/// any single run of that difficulty (a tile of tier N == 2^N).
/// `bestRankByDifficulty` is the best (lowest) leaderboard rank ever observed for
/// a difficulty; it is only populated lazily after a leaderboard fetch and is
/// absent (null) until then — rank-based predicates must treat absence as "not
/// yet unlocked", never as a failure.
class PlayerProgress {
  final int dailyActiveStreak;
  final Map<Difficulty, int> perTierStreak;
  final Map<Difficulty, int> bestTierByDifficulty;
  final Map<Difficulty, int> bestRankByDifficulty;

  const PlayerProgress({
    this.dailyActiveStreak = 0,
    this.perTierStreak = const {},
    this.bestTierByDifficulty = const {},
    this.bestRankByDifficulty = const {},
  });

  int tierStreak(Difficulty d) => perTierStreak[d] ?? 0;
  int bestTier(Difficulty d) => bestTierByDifficulty[d] ?? 0;
  int? bestRank(Difficulty d) => bestRankByDifficulty[d];

  /// The best (lowest) rank across all difficulties, or null if none observed.
  int? get bestRankAny {
    int? best;
    for (final r in bestRankByDifficulty.values) {
      if (best == null || r < best) best = r;
    }
    return best;
  }

  /// Highest tier reached in any difficulty (for tier-milestone achievements).
  int get bestTierAny {
    var m = 0;
    for (final t in bestTierByDifficulty.values) {
      if (t > m) m = t;
    }
    return m;
  }
}

/// Declarative badges. Each value carries a display label + a pure unlock
/// predicate over [PlayerProgress]. Definitions are local-first; rank-based ones
/// (e.g. [topTenFinish]) read rank data that is only present after a leaderboard
/// fetch, so they evaluate lazily and never block the result screen.
///
/// The enum `name` is the stable storage token (persisted in Hive) — never
/// localize it. Use [label] for display.
enum Achievement {
  /// Reach the 2048 tile (tier 11) on the Legendary board.
  firstLegendaryClear(
    label: 'Legend',
    description: 'Reach 2048 on Legendary',
  ),

  /// A 7-day daily-active streak (any tier counts toward the headline streak).
  sevenDayStreak(
    label: 'Week Warrior',
    description: '7-day streak',
  ),

  /// A 30-day daily-active streak.
  thirtyDayStreak(
    label: 'Unstoppable',
    description: '30-day streak',
  ),

  /// Finish in the global top 10 on any tier on any day.
  topTenFinish(
    label: 'Top 10',
    description: 'Finish top 10 on any tier',
  ),

  /// Build a streak of 7+ on every difficulty tier at once.
  tierMaster(
    label: 'Tier Master',
    description: '7-day streak on every tier',
  ),

  /// Reach the 1024 tile (tier 10) on any tier.
  highRoller(
    label: 'High Roller',
    description: 'Reach 1024 on any tier',
  );

  const Achievement({required this.label, required this.description});

  final String label;
  final String description;

  /// Pure unlock predicate. `topTenFinish` reads rank data that is only present
  /// after a leaderboard fetch; until then [PlayerProgress.bestRankAny] is null
  /// and the achievement stays locked (never errors).
  bool isUnlocked(PlayerProgress p) {
    switch (this) {
      case Achievement.firstLegendaryClear:
        return p.bestTier(Difficulty.legendary) >= 11;
      case Achievement.sevenDayStreak:
        return p.dailyActiveStreak >= 7;
      case Achievement.thirtyDayStreak:
        return p.dailyActiveStreak >= 30;
      case Achievement.topTenFinish:
        final r = p.bestRankAny;
        return r != null && r <= 10;
      case Achievement.tierMaster:
        return Difficulty.values.every((d) => p.tierStreak(d) >= 7);
      case Achievement.highRoller:
        return p.bestTierAny >= 10;
    }
  }
}

/// Evaluates the full set of currently-unlocked achievements for [p] (pure).
Set<Achievement> unlockedFor(PlayerProgress p) =>
    Achievement.values.where((a) => a.isUnlocked(p)).toSet();

/// Returns achievements newly unlocked by [p] given an [already]-unlocked set
/// (pure). Used to celebrate fresh unlocks on the result screen.
Set<Achievement> newlyUnlocked(
        PlayerProgress p, Set<Achievement> already) =>
    unlockedFor(p).difference(already);
