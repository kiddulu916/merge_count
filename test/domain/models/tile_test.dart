import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/models/tile.dart';

void main() {
  test('value is 2^tier', () {
    expect(const Tile(id: 0, tier: 1).value, 2);
    expect(const Tile(id: 0, tier: 11).value, 2048);
  });

  test('equality is by id and tier', () {
    expect(const Tile(id: 1, tier: 3), const Tile(id: 1, tier: 3));
    expect(const Tile(id: 1, tier: 3), isNot(const Tile(id: 2, tier: 3)));
  });

  test('copyWith changes tier but keeps id', () {
    final t = const Tile(id: 5, tier: 2).copyWith(tier: 3);
    expect(t.id, 5);
    expect(t.tier, 3);
  });

  test('round-trips through json', () {
    const t = Tile(id: 7, tier: 4);
    expect(Tile.fromJson(t.toJson()), t);
  });
}
