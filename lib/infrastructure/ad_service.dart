import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Isolates all google_mobile_ads lifecycle so the rest of the app never
/// imports the plugin directly.
class AdService {
  RewardedAd? _rewarded;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _preloadRewarded();
  }

  /// Builds a fresh banner ad. The caller is responsible for disposing it.
  BannerAd createBanner() {
    return BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    )..load();
  }

  void _preloadRewarded() {
    RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// Shows a rewarded ad. Calls [onReward] exactly once if the user earns the
  /// reward, then preloads the next ad. [onUnavailable] fires if none is ready.
  void showRewarded({
    required void Function() onReward,
    required void Function() onUnavailable,
  }) {
    final ad = _rewarded;
    if (ad == null) {
      onUnavailable();
      _preloadRewarded();
      return;
    }
    var rewarded = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        _preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewarded = null;
        onUnavailable();
        _preloadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, __) {
      if (!rewarded) {
        rewarded = true;
        onReward();
      }
    });
  }

  void dispose() {
    _rewarded?.dispose();
    _rewarded = null;
  }
}
