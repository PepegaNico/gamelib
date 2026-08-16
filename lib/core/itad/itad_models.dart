class ItadGameMatch {
  final String id;
  final String slug;
  final String title;

  ItadGameMatch({required this.id, required this.slug, required this.title});

  factory ItadGameMatch.fromJson(Map<String, dynamic> json) {
    return ItadGameMatch(
      id: json['id'] as String,
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Unbekanntes Spiel',
    );
  }
}

class ItadMoney {
  final double amount;
  final String currency;

  ItadMoney({required this.amount, required this.currency});

  factory ItadMoney.fromJson(Map<String, dynamic> json) {
    return ItadMoney(
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }

  String get formatted => '${amount.toStringAsFixed(2)} $currency';
}

class ItadDeal {
  final String shopName;
  final ItadMoney price;
  final ItadMoney regular;
  final int cutPercent;
  final String url;

  ItadDeal({
    required this.shopName,
    required this.price,
    required this.regular,
    required this.cutPercent,
    required this.url,
  });

  factory ItadDeal.fromJson(Map<String, dynamic> json) {
    return ItadDeal(
      shopName:
          (json['shop'] as Map<String, dynamic>?)?['name'] as String? ??
          'Unbekannt',
      price: ItadMoney.fromJson(json['price'] as Map<String, dynamic>),
      regular: ItadMoney.fromJson(json['regular'] as Map<String, dynamic>),
      cutPercent: (json['cut'] as int?) ?? 0,
      url: (json['url'] as String?) ?? '',
    );
  }
}

class ItadPriceInfo {
  final String gameId;
  final ItadMoney? historyLowAll;
  final List<ItadDeal> deals;

  ItadPriceInfo({
    required this.gameId,
    required this.historyLowAll,
    required this.deals,
  });

  factory ItadPriceInfo.fromJson(Map<String, dynamic> json) {
    final historyLow = json['historyLow'] as Map<String, dynamic>?;
    final allTime = historyLow?['all'] as Map<String, dynamic>?;
    final deals = (json['deals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ItadPriceInfo(
      gameId: json['id'] as String,
      historyLowAll: allTime != null ? ItadMoney.fromJson(allTime) : null,
      deals: deals.map(ItadDeal.fromJson).toList()
        ..sort((a, b) => a.price.amount.compareTo(b.price.amount)),
    );
  }

  ItadDeal? get bestDeal => deals.isEmpty ? null : deals.first;
}
