/// The kind of daily bonus goal (Connect-Merge). Seed-chosen per day.
enum ObjectiveKind { chainLength, reachTier }

/// A seed-derived daily objective. Progress is monotonic non-decreasing and
/// recomputed from each collapse, so it is fully reproducible on replay.
/// Completing it credits coins (client-side) — it NEVER affects score.
class DailyObjective {
  final ObjectiveKind kind;
  final int target;

  const DailyObjective({required this.kind, required this.target});

  /// New progress after a collapse of [chainLength] tiles that left the board at
  /// [highestTier]. Never regresses below [current].
  int progressAfter(int current,
      {required int chainLength, required int highestTier}) {
    final candidate = switch (kind) {
      ObjectiveKind.chainLength => chainLength,
      ObjectiveKind.reachTier => highestTier,
    };
    return candidate > current ? candidate : current;
  }

  bool isMet(int progress) => progress >= target;

  String get label => switch (kind) {
        ObjectiveKind.chainLength => 'Land a $target-chain',
        ObjectiveKind.reachTier => 'Reach tier $target (${1 << target})',
      };
}
