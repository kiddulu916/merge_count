import 'achievement.dart';

/// How a cosmetic tile theme is unlocked. Pure data — the predicate is
/// evaluated against [PlayerProgress] + the unlocked-achievement set, so it
/// stays testable and plugin-free. A [rewardedAd] cosmetic is unlocked by an
/// explicit ad grant (recorded in storage), not by progress.
enum CosmeticUnlock {
  /// Available from the start.
  free,

  /// Unlocked once the headline daily-active streak reaches a threshold.
  streak,

  /// Unlocked once a specific achievement is earned.
  achievement,

  /// Unlocked by watching a rewarded ad (recorded explicitly).
  rewardedAd,
}

/// A selectable tile theme. The enum `name` is the stable storage token (the
/// persisted `selectedCosmetic` / unlocked set) — never localize it. Colors live
/// here as a 12-entry ARGB ramp (tier 0 = empty slot .. tier 11 = 2048),
/// mirroring the original `tile_palette.dart` ramp so existing visuals are the
/// `classic` default.
enum Cosmetic {
  classic(
    label: 'Classic',
    unlock: CosmeticUnlock.free,
    colors: [
      0x14FFFFFF, // 0 empty slot
      0xFF3B82F6, // 1
      0xFF06B6D4, // 2
      0xFF10B981, // 3
      0xFF84CC16, // 4
      0xFFEAB308, // 5
      0xFFF59E0B, // 6
      0xFFF97316, // 7
      0xFFEF4444, // 8
      0xFFEC4899, // 9
      0xFFA855F7, // 10
      0xFF7C3AED, // 11 (2048)
    ],
  ),

  /// Unlocked at a 3-day streak. Cool ocean ramp.
  ocean(
    label: 'Ocean',
    unlock: CosmeticUnlock.streak,
    threshold: 3,
    colors: [
      0x14FFFFFF,
      0xFF0EA5E9,
      0xFF0284C7,
      0xFF0369A1,
      0xFF075985,
      0xFF14B8A6,
      0xFF0D9488,
      0xFF0F766E,
      0xFF22D3EE,
      0xFF38BDF8,
      0xFF818CF8,
      0xFF6366F1,
    ],
  ),

  /// Unlocked at a 7-day streak. Warm sunset ramp.
  sunset(
    label: 'Sunset',
    unlock: CosmeticUnlock.streak,
    threshold: 7,
    colors: [
      0x14FFFFFF,
      0xFFFB7185,
      0xFFF43F5E,
      0xFFE11D48,
      0xFFF97316,
      0xFFEA580C,
      0xFFF59E0B,
      0xFFD97706,
      0xFFFBBF24,
      0xFFFCD34D,
      0xFFF472B6,
      0xFFDB2777,
    ],
  ),

  /// Unlocked by the Legendary clear achievement. Royal gold/purple ramp.
  regal(
    label: 'Regal',
    unlock: CosmeticUnlock.achievement,
    achievement: Achievement.firstLegendaryClear,
    colors: [
      0x14FFFFFF,
      0xFFA78BFA,
      0xFF8B5CF6,
      0xFF7C3AED,
      0xFF6D28D9,
      0xFF5B21B6,
      0xFFFCD34D,
      0xFFFBBF24,
      0xFFF59E0B,
      0xFFD97706,
      0xFFC4B5FD,
      0xFFFDE68A,
    ],
  ),

  /// Unlocked by a rewarded ad. Monochrome neon ramp.
  neon(
    label: 'Neon',
    unlock: CosmeticUnlock.rewardedAd,
    colors: [
      0x14FFFFFF,
      0xFF22D3EE,
      0xFF2DD4BF,
      0xFF34D399,
      0xFF4ADE80,
      0xFFA3E635,
      0xFFFACC15,
      0xFFFB923C,
      0xFFF87171,
      0xFFE879F9,
      0xFFC084FC,
      0xFF818CF8,
    ],
  );

  const Cosmetic({
    required this.label,
    required this.unlock,
    required this.colors,
    this.threshold = 0,
    this.achievement,
  });

  final String label;
  final CosmeticUnlock unlock;

  /// 12-entry ARGB ramp (tier 0..11). Stored as ints to keep this model
  /// flutter-free (the presentation layer wraps them in `Color`).
  final List<int> colors;

  /// Streak threshold for [CosmeticUnlock.streak].
  final int threshold;

  /// Source achievement for [CosmeticUnlock.achievement].
  final Achievement? achievement;

  /// The default cosmetic (always available).
  static const Cosmetic defaultCosmetic = Cosmetic.classic;

  /// Pure: is this cosmetic unlocked given streak/achievements and the set of
  /// ad-unlocked cosmetics? `free` is always unlocked; `rewardedAd` only when it
  /// is explicitly present in [adUnlocked].
  bool isUnlocked({
    required int dailyActiveStreak,
    required Set<Achievement> achievements,
    required Set<Cosmetic> adUnlocked,
  }) {
    switch (unlock) {
      case CosmeticUnlock.free:
        return true;
      case CosmeticUnlock.streak:
        return dailyActiveStreak >= threshold;
      case CosmeticUnlock.achievement:
        return achievement != null && achievements.contains(achievement);
      case CosmeticUnlock.rewardedAd:
        return adUnlocked.contains(this);
    }
  }
}

/// The full set of unlocked cosmetics (pure). Always includes [Cosmetic.classic].
Set<Cosmetic> unlockedCosmetics({
  required int dailyActiveStreak,
  required Set<Achievement> achievements,
  required Set<Cosmetic> adUnlocked,
}) =>
    Cosmetic.values
        .where((c) => c.isUnlocked(
              dailyActiveStreak: dailyActiveStreak,
              achievements: achievements,
              adUnlocked: adUnlocked,
            ))
        .toSet();
