class WishlistEntry {
  final String itadGameId;
  final String title;
  final String slug;

  /// If set, the entry is flagged once the best current price drops to or
  /// below this amount (see WishlistState.alertedEntries).
  final double? targetPriceAmount;
  final DateTime addedAt;

  /// Set when this entry came from a Steam wishlist import — lets the UI
  /// show the Steam header image without a separate lookup, and is null
  /// for entries added manually via ITAD search.
  final int? steamAppId;

  WishlistEntry({
    required this.itadGameId,
    required this.title,
    required this.slug,
    required this.targetPriceAmount,
    required this.addedAt,
    this.steamAppId,
  });

  WishlistEntry copyWith({
    double? targetPriceAmount,
    bool clearTarget = false,
  }) {
    return WishlistEntry(
      itadGameId: itadGameId,
      title: title,
      slug: slug,
      targetPriceAmount: clearTarget
          ? null
          : (targetPriceAmount ?? this.targetPriceAmount),
      addedAt: addedAt,
      steamAppId: steamAppId,
    );
  }

  factory WishlistEntry.fromJson(Map<String, dynamic> json) {
    return WishlistEntry(
      itadGameId: json['itadGameId'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      targetPriceAmount: (json['targetPriceAmount'] as num?)?.toDouble(),
      addedAt: DateTime.parse(json['addedAt'] as String),
      steamAppId: (json['steamAppId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'itadGameId': itadGameId,
    'title': title,
    'slug': slug,
    'targetPriceAmount': targetPriceAmount,
    'addedAt': addedAt.toIso8601String(),
    'steamAppId': steamAppId,
  };
}
