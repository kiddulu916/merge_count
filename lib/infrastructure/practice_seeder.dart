import 'dart:math';

import '../domain/engine/daily_seeder.dart';
import '../domain/engine/prng.dart';
import '../domain/models/difficulty.dart';

/// Off-leaderboard endless play. A practice round is just a [DailyStart] seeded
/// from a RANDOM key (not a UTC date), so it is NOT reproducible across players
/// and therefore CANNOT be replay-verified or submitted to any leaderboard.
///
/// CRITICAL FAIRNESS INVARIANT: practice mode has no submit/score path. This
/// class only generates boards; nothing here references the leaderboard or
/// submit services, and the practice screen never calls them. The randomized
/// seed key makes a submission meaningless even if one were ever attempted.
class PracticeSeeder {
  final Random _random;

  /// [random] is injectable for deterministic tests; production uses a
  /// time-seeded [Random].
  PracticeSeeder({Random? random}) : _random = random ?? Random();

  /// A unique, non-date "date" component for the seeder. Prefixed `practice:` so
  /// it can never collide with a real daily key (`YYYY-MM-DD`).
  String nextSeedKey(Difficulty difficulty) {
    final salt = _random.nextInt(1 << 31);
    return 'practice:$salt';
  }

  /// Generate a fresh, playable practice board for [difficulty]. Reuses the
  /// exact same engine generation as the daily seeder (so boards are guaranteed
  /// valid: correct starting fill, full drop schedule) keyed off a random seed.
  /// Also returns the landing PRNG and seed key for the round.
  PracticeRound generate(Difficulty difficulty) {
    final key = nextSeedKey(difficulty);
    final seeder = DailySeeder(key, difficulty);
    return PracticeRound(
      seedKey: key,
      difficulty: difficulty,
      start: seeder.generate(),
      landing: seeder.landingPrng(),
    );
  }
}

/// Everything a practice round needs to play locally. Crucially carries NO
/// submission affordance — there is no date, no leaderboard handle, nothing the
/// submit path could consume.
class PracticeRound {
  final String seedKey;
  final Difficulty difficulty;
  final DailyStart start;
  final Prng landing;

  const PracticeRound({
    required this.seedKey,
    required this.difficulty,
    required this.start,
    required this.landing,
  });
}
