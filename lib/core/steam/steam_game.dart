import 'package:gamelib/core/models/game_platform.dart';
import 'package:gamelib/core/models/library_game.dart';

class SteamGame implements LibraryGame {
  final int appId;
  @override
  final String name;
  final int playtimeForeverMinutes;
  final int playtime2WeeksMinutes;
  @override
  final DateTime? lastPlayed;

  /// SteamID64 of the connected account this copy was fetched from — needed
  /// to fetch achievements for the right account once a library can merge
  /// games owned across several connected Steam accounts.
  final String steamId;

  SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeForeverMinutes,
    required this.playtime2WeeksMinutes,
    required this.lastPlayed,
    required this.steamId,
  });

  factory SteamGame.fromJson(Map<String, dynamic> json, {required String steamId}) {
    final lastPlayedEpoch = json['rtime_last_played'] as int?;
    return SteamGame(
      appId: json['appid'] as int,
      name: (json['name'] as String?) ?? 'Unbekanntes Spiel',
      playtimeForeverMinutes: (json['playtime_forever'] as int?) ?? 0,
      playtime2WeeksMinutes: (json['playtime_2weeks'] as int?) ?? 0,
      lastPlayed: (lastPlayedEpoch != null && lastPlayedEpoch > 0)
          ? DateTime.fromMillisecondsSinceEpoch(lastPlayedEpoch * 1000)
          : null,
      steamId: steamId,
    );
  }

  @override
  String get id => 'steam:$appId';

  @override
  double get playtimeForeverHours => playtimeForeverMinutes / 60;

  @override
  bool get hasPlaytimeData => true;

  @override
  String get headerImageUrl =>
      'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg';

  String get libraryCapsuleUrl =>
      'https://cdn.akamai.steamstatic.com/steam/apps/$appId/library_600x900.jpg';

  @override
  String get storePageUrl => 'https://store.steampowered.com/app/$appId/';

  /// Opens the Steam client and launches the game directly.
  String get launchUrl => 'steam://run/$appId';

  @override
  String get primaryActionLabel => 'Spiel starten';

  @override
  String get primaryActionUrl => launchUrl;

  @override
  GamePlatform get platform => GamePlatform.steam;

  @override
  bool get hasBeenPlayed => playtimeForeverMinutes > 0;
}
