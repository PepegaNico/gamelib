import 'dart:io';

import '../models/game_platform.dart';
import '../models/library_game.dart';

/// An Xbox game — from one or both of two sources:
/// - installed locally on this PC through the Xbox app / Microsoft Store
///   (see XboxLocalScanner; enriched from the Store catalog), and/or
/// - the signed-in Xbox account's title history (see XboxLiveService),
///   which covers consoles and cloud too and adds last-played and
///   achievement progress.
/// XboxState merges both by package family name.
class XboxGame implements LibraryGame {
  /// Set for PC/Store titles; console-only titles have none.
  final String? packageFamilyName;

  /// Xbox Live title id — set for games from the account's title history.
  final String? titleId;

  /// Application id inside the package — together with
  /// [packageFamilyName] it forms the AUMID Windows launches. Null for
  /// games that aren't installed on this PC.
  final String? appId;
  @override
  String name;

  /// True on the Windows device that actually has it installed.
  final bool isInstalled;

  String? productId;
  String? posterUrl;
  String? heroUrl;
  String? description;
  String? developer;

  DateTime? lastPlayedAt;
  int? achievementsEarned;
  int? achievementsTotal;
  int? gamerscoreEarned;
  int? gamerscoreTotal;

  /// e.g. ["XboxSeries", "PC"].
  List<String> devices;

  XboxGame({
    this.packageFamilyName,
    this.titleId,
    this.appId,
    required this.name,
    this.isInstalled = true,
    this.productId,
    this.posterUrl,
    this.heroUrl,
    this.description,
    this.developer,
    this.lastPlayedAt,
    this.achievementsEarned,
    this.achievementsTotal,
    this.gamerscoreEarned,
    this.gamerscoreTotal,
    this.devices = const [],
  });

  factory XboxGame.fromTitleHub(Map<String, dynamic> json) {
    final images = ((json['images'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    String? image(List<String> types) {
      for (final type in types) {
        final match = images.where((i) => i['type'] == type).firstOrNull;
        if (match != null) return _https(match['url'] as String?);
      }
      return null;
    }

    final achievement = json['achievement'] as Map<String, dynamic>?;
    final detail = json['detail'] as Map<String, dynamic>?;
    final history = json['titleHistory'] as Map<String, dynamic>?;
    final pfn = json['pfn'] as String?;

    return XboxGame(
      packageFamilyName: (pfn == null || pfn.isEmpty) ? null : pfn,
      titleId: json['titleId']?.toString(),
      name: (json['name'] as String?) ?? 'Unbekanntes Spiel',
      isInstalled: false,
      productId: detail?['productId'] as String?,
      posterUrl:
          image(['Poster', 'BoxArt']) ??
          _https(json['displayImage'] as String?),
      heroUrl: image(['SuperHeroArt', 'TitledHeroArt', 'Screenshot']),
      description:
          (detail?['shortDescription'] as String?) ??
          (detail?['description'] as String?),
      developer:
          (detail?['developerName'] as String?) ??
          (detail?['publisherName'] as String?),
      lastPlayedAt: DateTime.tryParse(
        (history?['lastTimePlayed'] as String?) ?? '',
      )?.toLocal(),
      achievementsEarned: (achievement?['currentAchievements'] as num?)
          ?.toInt(),
      achievementsTotal: (achievement?['totalAchievements'] as num?)?.toInt(),
      gamerscoreEarned: (achievement?['currentGamerscore'] as num?)?.toInt(),
      gamerscoreTotal: (achievement?['totalGamerscore'] as num?)?.toInt(),
      devices: ((json['devices'] as List?) ?? []).cast<String>(),
    );
  }

  static String? _https(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('//')) return 'https:$url';
    return url.replaceFirst('http://', 'https://');
  }

  /// This locally installed game, with the account's play data from the
  /// matching title-history entry filled in.
  XboxGame mergedWith(XboxGame cloud) => XboxGame(
    packageFamilyName: packageFamilyName,
    titleId: cloud.titleId,
    appId: appId,
    name: name,
    isInstalled: isInstalled,
    productId: productId ?? cloud.productId,
    posterUrl: posterUrl ?? cloud.posterUrl,
    heroUrl: heroUrl ?? cloud.heroUrl,
    description: description ?? cloud.description,
    developer: developer ?? cloud.developer,
    lastPlayedAt: cloud.lastPlayedAt,
    achievementsEarned: cloud.achievementsEarned,
    achievementsTotal: cloud.achievementsTotal,
    gamerscoreEarned: cloud.gamerscoreEarned,
    gamerscoreTotal: cloud.gamerscoreTotal,
    devices: cloud.devices,
  );

  bool get hasAchievements => (achievementsTotal ?? 0) > 0;

  @override
  String get id => 'xbox:${packageFamilyName ?? titleId ?? name}';

  @override
  GamePlatform get platform => GamePlatform.xbox;

  @override
  String get headerImageUrl => heroUrl ?? posterUrl ?? '';

  @override
  String get coverImageUrl => posterUrl ?? headerImageUrl;

  @override
  bool get coverIsPortrait => posterUrl != null;

  @override
  String get storePageUrl => productId != null
      ? 'https://www.xbox.com/de-CH/games/store/_/$productId'
      : 'https://www.xbox.com/de-CH/search?q=${Uri.encodeComponent(name)}';

  @override
  bool get hasPlaytimeData => false;

  @override
  double get playtimeForeverHours => 0;

  /// Xbox doesn't report minutes played here, but a title only appears in
  /// the history once it has been started.
  @override
  bool get hasBeenPlayed => lastPlayedAt != null;

  @override
  DateTime? get lastPlayed => lastPlayedAt;

  @override
  bool get canLaunch => isInstalled && appId != null;

  @override
  String get primaryActionLabel =>
      canLaunch ? 'Spiel starten' : 'Im Store öffnen';

  /// Not launchable as a URL — packaged apps start via their AUMID, see
  /// [launch]. Used as the fallback target where only a URL fits.
  @override
  String get primaryActionUrl => storePageUrl;

  /// Starts the installed game the same way the Start menu does.
  Future<bool> launch() async {
    if (!Platform.isWindows || !canLaunch) return false;
    try {
      await Process.start('explorer.exe', [
        'shell:AppsFolder\\$packageFamilyName!$appId',
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toSyncJson() => {
    'packageFamilyName': packageFamilyName,
    'titleId': titleId,
    'appId': appId,
    'name': name,
    'productId': productId,
    'posterUrl': posterUrl,
    'heroUrl': heroUrl,
    'description': description,
    'developer': developer,
    'lastPlayed': lastPlayedAt?.toUtc().toIso8601String(),
    'achievementsEarned': achievementsEarned,
    'achievementsTotal': achievementsTotal,
    'gamerscoreEarned': gamerscoreEarned,
    'gamerscoreTotal': gamerscoreTotal,
    'devices': devices,
  };

  factory XboxGame.fromSyncJson(Map<String, dynamic> json) => XboxGame(
    packageFamilyName: json['packageFamilyName'] as String?,
    titleId: json['titleId'] as String?,
    appId: json['appId'] as String?,
    name: json['name'] as String,
    isInstalled: false,
    productId: json['productId'] as String?,
    posterUrl: json['posterUrl'] as String?,
    heroUrl: json['heroUrl'] as String?,
    description: json['description'] as String?,
    developer: json['developer'] as String?,
    lastPlayedAt: DateTime.tryParse((json['lastPlayed'] as String?) ?? '')
        ?.toLocal(),
    achievementsEarned: (json['achievementsEarned'] as num?)?.toInt(),
    achievementsTotal: (json['achievementsTotal'] as num?)?.toInt(),
    gamerscoreEarned: (json['gamerscoreEarned'] as num?)?.toInt(),
    gamerscoreTotal: (json['gamerscoreTotal'] as num?)?.toInt(),
    devices: ((json['devices'] as List?) ?? []).cast<String>(),
  );
}
