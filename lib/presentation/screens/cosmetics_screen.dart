import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/engagement_cubit.dart';
import '../../domain/models/cosmetic.dart';
import '../../infrastructure/ad_service.dart';
import '../theme/tile_palette.dart';

/// Pick a tile theme. Unlocked cosmetics are selectable; locked ones show their
/// unlock requirement. A rewarded-ad cosmetic can be unlocked in-place.
class CosmeticsScreen extends StatelessWidget {
  final EngagementCubit engagement;
  final AdService adService;

  const CosmeticsScreen({
    super.key,
    required this.engagement,
    required this.adService,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EngagementCubit, EngagementState>(
      bloc: engagement,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF12141C),
          appBar: AppBar(
            backgroundColor: const Color(0xFF12141C),
            foregroundColor: Colors.white,
            title: const Text('Tile Themes'),
          ),
          body: ListView(
            key: const Key('cosmetics-list'),
            padding: const EdgeInsets.all(16),
            children: [
              for (final c in Cosmetic.values)
                _CosmeticTile(
                  cosmetic: c,
                  selected: state.selectedCosmetic == c,
                  unlocked: state.unlockedCosmetics.contains(c),
                  onSelect: () => engagement.selectCosmetic(c),
                  onUnlockViaAd: c.unlock == CosmeticUnlock.rewardedAd
                      ? () => _unlockViaAd(context, c)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  void _unlockViaAd(BuildContext context, Cosmetic c) {
    adService.showRewarded(
      onReward: () => engagement.grantAdCosmetic(c),
      onUnavailable: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No ad available right now.')),
          );
        }
      },
    );
  }
}

class _CosmeticTile extends StatelessWidget {
  final Cosmetic cosmetic;
  final bool selected;
  final bool unlocked;
  final VoidCallback onSelect;
  final VoidCallback? onUnlockViaAd;

  const _CosmeticTile({
    required this.cosmetic,
    required this.selected,
    required this.unlocked,
    required this.onSelect,
    this.onUnlockViaAd,
  });

  String get _unlockHint => switch (cosmetic.unlock) {
        CosmeticUnlock.free => 'Default',
        CosmeticUnlock.streak => 'Reach a ${cosmetic.threshold}-day streak',
        CosmeticUnlock.achievement =>
          'Earn: ${cosmetic.achievement?.label ?? ''}',
        CosmeticUnlock.rewardedAd => 'Watch an ad to unlock',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1B1E2A),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('cosmetic-${cosmetic.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: unlocked ? onSelect : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Mini color ramp preview (tiers 1..5).
                Row(
                  children: [
                    for (var tier = 1; tier <= 5; tier++)
                      Container(
                        width: 14,
                        height: 28,
                        color: TilePalette.colorFor(cosmetic, tier),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cosmetic.label,
                          style: TextStyle(
                              color: unlocked ? Colors.white : Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      if (!unlocked)
                        Text(_unlockHint,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: Colors.greenAccent)
                else if (!unlocked && onUnlockViaAd != null)
                  TextButton(
                    key: Key('cosmetic-ad-${cosmetic.name}'),
                    onPressed: onUnlockViaAd,
                    child: const Text('Unlock'),
                  )
                else if (!unlocked)
                  const Icon(Icons.lock_outline, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
