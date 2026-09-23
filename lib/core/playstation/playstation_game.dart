import '../models/game_platform.dart';
import '../models/library_game.dart';

/// A PS4/PS5 game from the PlayStation account's played-games list (see
/// PsnApiService). Console games can't be started from the PC, so the
/// primary action opens the PlayStation Store page.
class PlaystationGame implements LibraryGame {
  final String titleId;
  @override
  final String name;

  /// PlayStation Store concept id — the stable per-game store page.
  final String? conceptId;

  /// "ps5_native_game", "ps4_game", …
  final String category;
  final String? iconUrl;
  final String? heroUrl;
  final int playtimeMinutes;
  final int playCount;
  @override
  final DateTime? lastPlayed;

  PlaystationGame({
    required this.titleId,
    required this.name,
    required this.category,
    this.conceptId,
    this.iconUrl,
    this.heroUrl,
    this.playtimeMinutes = 0,
    this.playCount = 0,
    this.lastPlayed,
  });

  factory PlaystationGame.fromGameList(Map<String, dynamic> json) {
    final concept = json['concept'] as Map<String, dynamic>?;
    final media = json['media'] as Map<String, dynamic>?;
    final images = [
      ...((media?['images'] as List?) ?? []),
      ...(((concept?['media'] as Map<String, dynamic>?)?['images'] as List?) ??
          []),
    ].cast<Map<String, dynamic>>();
    String? image(List<String> types) {
      for (final type in types) {
        final match = images.where((i) => i['type'] == type).firstOrNull;
        if (match != null) return match['url'] as String?;
      }
      return null;
    }

    return PlaystationGame(
      titleId: json['titleId'] as String,
      name:
          (json['localizedName'] as String?) ??
          (json['name'] as String?) ??
          'Unbekanntes Spiel',
      category: (json['category'] as String?) ?? '',
      conceptId: concept?['id']?.toString(),
      iconUrl:
          (json['localizedImageUrl'] as String?) ??
          (json['imageUrl'] as String?),
      heroUrl: image([
        'GAMEHUB_COVER_ART',
        'FOUR_BY_THREE_BANNER',
        'BACKGROUND',
      ]),
      playtimeMinutes: parseIsoDurationMinutes(json['playDuration'] as String?),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      lastPlayed: DateTime.tryParse(
        (json['lastPlayedDateTime'] as String?) ?? '',
      )?.toLocal(),
    );
  }

  /// "PT32H15M3S" → 1935.
  static int parseIsoDurationMinutes(String? value) {
    if (value == null) return 0;
    final match = RegExp(r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$')
        .firstMatch(value);
    if (match == null) return 0;
    int part(int i) => int.tryParse(match.group(i) ?? '') ?? 0;
    return part(1) * 24 * 60 + part(2) * 60 + part(3);
  }

  String get consoleLabel => category.startsWith('ps5') ? 'PS5' : 'PS4';

  @override
  String get id => 'playstation:$titleId';

  @override
  GamePlatform get platform => GamePlatform.playstation;

  @override
  String get headerImageUrl => heroUrl ?? iconUrl ?? '';

  /// PlayStation only has square icons and wide banners — no portrait art.
  @override
  String get coverImageUrl => iconUrl ?? headerImageUrl;

  @override
  bool get coverIsPortrait => false;

  @override
  String get storePageUrl => conceptId != null
      ? 'https://store.playstation.com/de-ch/concept/$conceptId'
      : 'https://store.playstation.com/de-ch/search/${Uri.encodeComponent(name)}';

  @override
  bool get hasPlaytimeData => true;

  @override
  double get playtimeForeverHours => playtimeMinutes / 60;

  @override
  bool get hasBeenPlayed => playtimeMinutes > 0 || playCount > 0;

  @override
  bool get canLaunch => false;

  @override
  String get primaryActionLabel => 'Im PlayStation Store öffnen';

  @override
  String get primaryActionUrl => storePageUrl;

  Map<String, dynamic> toSyncJson() => {
    'titleId': titleId,
    'name': name,
    'category': category,
    'conceptId': conceptId,
    'iconUrl': iconUrl,
    'heroUrl': heroUrl,
    'playtimeMinutes': playtimeMinutes,
    'playCount': playCount,
    'lastPlayed': lastPlayed?.toUtc().toIso8601String(),
  };

  factory PlaystationGame.fromSyncJson(Map<String, dynamic> json) =>
      PlaystationGame(
        titleId: json['titleId'] as String,
        name: json['name'] as String,
        category: (json['category'] as String?) ?? '',
        conceptId: json['conceptId'] as String?,
        iconUrl: json['iconUrl'] as String?,
        heroUrl: json['heroUrl'] as String?,
        playtimeMinutes: (json['playtimeMinutes'] as num?)?.toInt() ?? 0,
        playCount: (json['playCount'] as num?)?.toInt() ?? 0,
        lastPlayed: DateTime.tryParse((json['lastPlayed'] as String?) ?? '')
            ?.toLocal(),
      );
}
