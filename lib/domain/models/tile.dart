/// A live tile. [id] is a stable identity used as the widget key so the UI can
/// animate a tile as it slides/merges. [tier] is 1..kMaxTier; value is 2^tier.
class Tile {
  final int id;
  final int tier;

  const Tile({required this.id, required this.tier});

  int get value => 1 << tier;

  Tile copyWith({int? tier}) => Tile(id: id, tier: tier ?? this.tier);

  Map<String, dynamic> toJson() => {'id': id, 'tier': tier};

  static Tile fromJson(Map<String, dynamic> j) =>
      Tile(id: j['id'] as int, tier: j['tier'] as int);

  @override
  bool operator ==(Object other) =>
      other is Tile && other.id == id && other.tier == tier;

  @override
  int get hashCode => Object.hash(id, tier);
}
