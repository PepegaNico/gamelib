class EpicStoreListing {
  final String id;
  final String title;
  final String? description;
  final String? developerName;
  final List<String> categoryPaths;
  final String? imageUrl;
  final String productSlug;
  final int? originalPriceCents;
  final int? discountPriceCents;
  final String? currencyCode;

  EpicStoreListing({
    required this.id,
    required this.title,
    required this.description,
    required this.developerName,
    required this.categoryPaths,
    required this.imageUrl,
    required this.productSlug,
    required this.originalPriceCents,
    required this.discountPriceCents,
    required this.currencyCode,
  });

  factory EpicStoreListing.fromJson(Map<String, dynamic> json) {
    final images =
        (json['keyImages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final preferredImage = images.firstWhere(
      (img) => (img['type'] as String?)?.contains('Wide') ?? false,
      orElse: () => images.isNotEmpty ? images.first : <String, dynamic>{},
    );

    final price = json['price'] as Map<String, dynamic>?;
    final totalPrice = price?['totalPrice'] as Map<String, dynamic>?;

    // Generic store taxonomy paths like "games/edition/base" — not real
    // genre names (Epic has no public genre-name API), but still useful
    // as lightweight tags.
    final categories =
        (json['categories'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((c) => c['path'] as String? ?? '')
            .where((p) => p.isNotEmpty && p.contains('/'))
            .toList() ??
        [];

    return EpicStoreListing(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Unbekanntes Spiel',
      description: json['description'] as String?,
      developerName:
          (json['seller'] as Map<String, dynamic>?)?['name'] as String?,
      categoryPaths: categories,
      imageUrl: preferredImage['url'] as String?,
      productSlug:
          (json['productSlug'] as String?) ??
          (json['urlSlug'] as String?) ??
          '',
      originalPriceCents: totalPrice?['originalPrice'] as int?,
      discountPriceCents: totalPrice?['discountPrice'] as int?,
      currencyCode: totalPrice?['currencyCode'] as String?,
    );
  }

  bool get isOnSale =>
      originalPriceCents != null &&
      discountPriceCents != null &&
      discountPriceCents! < originalPriceCents!;

  bool get isFree => discountPriceCents == 0;

  String get storeUrl => 'https://store.epicgames.com/en-US/p/$productSlug';

  String? get formattedPrice {
    if (discountPriceCents == null || currencyCode == null) return null;
    if (isFree) return 'Kostenlos';
    return '${(discountPriceCents! / 100).toStringAsFixed(2)} $currencyCode';
  }

  String? get formattedOriginalPrice {
    if (originalPriceCents == null || currencyCode == null || !isOnSale) {
      return null;
    }
    return '${(originalPriceCents! / 100).toStringAsFixed(2)} $currencyCode';
  }
}
