import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/infrastructure/ad_config.dart';

void main() {
  test('uses Google test unit IDs while useTestAds is true', () {
    expect(AdConfig.useTestAds, isTrue);
    expect(AdConfig.bannerUnitId, isNotEmpty);
    expect(AdConfig.rewardedUnitId, isNotEmpty);
  });
}
