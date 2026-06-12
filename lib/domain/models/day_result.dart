import 'difficulty.dart';

/// An immutable summary of one completed `(date, difficulty)` run, persisted to
/// the append-only history log so the stats calendar can render past days
/// Wordle-style.
///
/// Pure data — no plugin dependencies — so it stays testable. The [date] is the
/// canonical UTC `YYYY-MM-DD` string (same form the seeder/storage use
/// everywhere), kept as a string to avoid local/UTC drift.
class DayResult {
  /// Canonical UTC date string (`YYYY-MM-DD`) the run belongs to.
  final String date;

  /// Which tier the run was played on.
  final Difficulty difficulty;

  /// Final board score of the run.
  final int score;

  /// Highest tile tier reached during the run.
  final int highestTier;

  /// Factual end-of-run state: true when the run ended because the move budget
  /// was spent ([GameStatus.outOfMoves]), false when it dead-ended early
  /// (deadlocked). This is NOT a win/loss — there is no win condition (the game
  /// is a high-score chase); a high-scoring deadlock is a strong day, not a
  /// loss. The calendar reads OUTCOME QUALITY (score/highestTier) instead.
  final bool endedOutOfMoves;

  const DayResult({
    required this.date,
    required this.difficulty,
    required this.score,
    required this.highestTier,
    required this.endedOutOfMoves,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'difficulty': difficulty.name,
        'score': score,
        'highestTier': highestTier,
        'endedOutOfMoves': endedOutOfMoves,
      };

  static DayResult fromJson(Map<String, dynamic> j) => DayResult(
        date: j['date'] as String,
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        score: j['score'] as int,
        highestTier: j['highestTier'] as int,
        // Migration-free: accept the legacy `win` key as a fallback for records
        // written before this field was renamed (it carried the same fact).
        endedOutOfMoves:
            (j['endedOutOfMoves'] as bool?) ?? (j['win'] as bool? ?? false),
      );

  @override
  bool operator ==(Object other) =>
      other is DayResult &&
      other.date == date &&
      other.difficulty == difficulty &&
      other.score == score &&
      other.highestTier == highestTier &&
      other.endedOutOfMoves == endedOutOfMoves;

  @override
  int get hashCode =>
      Object.hash(date, difficulty, score, highestTier, endedOutOfMoves);

  @override
  String toString() =>
      'DayResult(date: $date, difficulty: ${difficulty.name}, '
      'score: $score, highestTier: $highestTier, '
      'endedOutOfMoves: $endedOutOfMoves)';
}
