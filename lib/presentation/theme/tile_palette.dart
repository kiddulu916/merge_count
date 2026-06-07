import 'package:flutter/material.dart';

import '../../domain/models/cosmetic.dart';

/// Maps a tier to its tile color. Tier 0 (empty) uses a translucent slot color.
///
/// Phase 4: tile colors are now driven by the selectable [Cosmetic] palettes
/// (see `domain/models/cosmetic.dart`). The static [colorForTier] keeps the
/// original `classic` ramp as the default so existing callers/tests are
/// unaffected; pass a [Cosmetic] to render an unlocked theme.
class TilePalette {
  const TilePalette._();

  /// Default (classic) tier color. Backward-compatible with Phase 1 callers.
  static Color colorForTier(int tier) => colorFor(Cosmetic.classic, tier);

  /// Tier color for a specific cosmetic palette.
  static Color colorFor(Cosmetic cosmetic, int tier) {
    final ramp = cosmetic.colors;
    return Color(ramp[tier.clamp(0, ramp.length - 1)]);
  }

  static Color textColorForTier(int tier) => Colors.white;
}
