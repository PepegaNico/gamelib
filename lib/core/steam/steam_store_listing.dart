class SteamStoreListing {
  final int appId;
  final String name;
  final String imageUrl;
  final int? initialPriceCents;
  final int? finalPriceCents;
  final String? currency;

  SteamStoreListing({
    required this.appId,
    required this.name,
    required this.imageUrl,
    required this.initialPriceCents,
    required this.finalPriceCents,
    required this.currency,
  });

  factory SteamStoreListing.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>?;
    return SteamStoreListing(
      appId: json['id'] as int,
      name: (json['name'] as String?) ?? 'Unbekanntes Spiel',
      imageUrl: (json['tiny_image'] as String?) ?? '',
      initialPriceCents: price?['initial'] as int?,
      finalPriceCents: price?['final'] as int?,
      currency: price?['currency'] as String?,
    );
  }

  /// The `featuredcategories` endpoint (specials/top_sellers/new_releases)
  /// uses a different, flatter shape than storesearch's nested `price`
  /// object — prices sit at the top level here.
  factory SteamStoreListing.fromFeaturedJson(Map<String, dynamic> json) {
    return SteamStoreListing(
      appId: json['id'] as int,
      name: (json['name'] as String?) ?? 'Unbekanntes Spiel',
      imageUrl:
          (json['header_image'] as String?) ??
          (json['large_capsule_image'] as String?) ??
          '',
      initialPriceCents: json['original_price'] as int?,
      finalPriceCents: json['final_price'] as int?,
      currency: json['currency'] as String?,
    );
  }

  bool get isOnSale =>
      initialPriceCents != null &&
      finalPriceCents != null &&
      finalPriceCents! < initialPriceCents!;

  bool get isFree => finalPriceCents == 0;

  String get storeUrl => 'https://store.steampowered.com/app/$appId/';

  String? get formattedPrice {
    if (finalPriceCents == null || currency == null) return null;
    if (isFree) return 'Kostenlos';
    return '${(finalPriceCents! / 100).toStringAsFixed(2)} $currency';
  }

  String? get formattedOriginalPrice {
    if (initialPriceCents == null || currency == null || !isOnSale) return null;
    return '${(initialPriceCents! / 100).toStringAsFixed(2)} $currency';
  }
}
