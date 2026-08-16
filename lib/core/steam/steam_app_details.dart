class SteamAppDetails {
  /// "game", "dlc", "demo", "music", "mod", "video", …
  final String? type;
  final String? shortDescription;
  final List<String> genres;
  final List<String> developers;
  final List<String> publishers;
  final String? releaseDate;
  final int? metacriticScore;
  final String? metacriticUrl;
  final bool fullControllerSupport;
  final bool supportsGerman;
  final List<String> screenshotUrls;

  SteamAppDetails({
    required this.type,
    required this.shortDescription,
    required this.genres,
    required this.developers,
    required this.publishers,
    required this.releaseDate,
    required this.metacriticScore,
    required this.metacriticUrl,
    required this.fullControllerSupport,
    required this.supportsGerman,
    required this.screenshotUrls,
  });

  factory SteamAppDetails.fromJson(Map<String, dynamic> data) {
    final genres =
        (data['genres'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((g) => g['description'] as String)
            .toList() ??
        [];
    final categories =
        (data['categories'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((c) => c['description'] as String)
            .toList() ??
        [];
    final screenshots =
        (data['screenshots'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((s) => s['path_thumbnail'] as String)
            .take(6)
            .toList() ??
        [];
    final metacritic = data['metacritic'] as Map<String, dynamic>?;
    final supportedLanguages = (data['supported_languages'] as String?) ?? '';

    return SteamAppDetails(
      type: data['type'] as String?,
      shortDescription: data['short_description'] as String?,
      genres: genres,
      developers: (data['developers'] as List?)?.cast<String>() ?? [],
      publishers: (data['publishers'] as List?)?.cast<String>() ?? [],
      releaseDate:
          (data['release_date'] as Map<String, dynamic>?)?['date'] as String?,
      metacriticScore: metacritic?['score'] as int?,
      metacriticUrl: metacritic?['url'] as String?,
      fullControllerSupport: categories.any(
        (c) => c.toLowerCase().contains('controller'),
      ),
      supportsGerman:
          supportedLanguages.toLowerCase().contains('german') ||
          supportedLanguages.toLowerCase().contains('deutsch'),
      screenshotUrls: screenshots,
    );
  }
}
