import '../models/game_platform.dart';
import '../models/library_game.dart';

/// itch.io's API doesn't expose playtime, so this always reports
/// [hasPlaytimeData] as false — sort/filter code must treat that as
/// "unknown", not "never played". Unlike Epic, the owned-keys response
/// already includes a real description/classification/release date
/// directly, so no separate lookup is needed for the detail screen.
class ItchioGame implements LibraryGame {
  final int gameId;
  @override
  final String name;
  final String coverUrl;
  final String pageUrl;
  final String author;
  final String? shortText;
  final String? classification;
  final DateTime? publishedAt;

  ItchioGame({
    required this.gameId,
    required this.name,
    required this.coverUrl,
    required this.pageUrl,
    required this.author,
    required this.shortText,
    required this.classification,
    required this.publishedAt,
  });

  factory ItchioGame.fromDownloadKeyJson(Map<String, dynamic> json) {
    final game = json['game'] as Map<String, dynamic>? ?? {};
    final user = game['user'] as Map<String, dynamic>?;
    return ItchioGame(
      gameId: (game['id'] as int?) ?? 0,
      name: (game['title'] as String?) ?? 'Unbekanntes Spiel',
      coverUrl: (game['cover_url'] as String?) ?? '',
      pageUrl: (game['url'] as String?) ?? '',
      author: (user?['username'] as String?) ?? '',
      shortText: game['short_text'] as String?,
      classification: game['classification'] as String?,
      publishedAt: DateTime.tryParse((game['published_at'] as String?) ?? ''),
    );
  }

  @override
  String get id => 'itchio:$gameId';

  @override
  GamePlatform get platform => GamePlatform.itchio;

  @override
  String get headerImageUrl => coverUrl;

  @override
  String get storePageUrl => pageUrl;

  @override
  bool get hasPlaytimeData => false;

  @override
  double get playtimeForeverHours => 0;

  @override
  bool get hasBeenPlayed => false;

  @override
  DateTime? get lastPlayed => null;

  @override
  String get primaryActionLabel => 'Auf itch.io öffnen';

  @override
  String get primaryActionUrl => pageUrl;
}
