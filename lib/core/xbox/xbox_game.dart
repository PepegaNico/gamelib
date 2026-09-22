import 'dart:io';

import '../models/game_platform.dart';
import '../models/library_game.dart';

/// A PC game installed through the Xbox app / Microsoft Store (a packaged
/// app with a `MicrosoftGame.config`, see XboxLocalScanner). Artwork and
/// description come from Microsoft's public store catalog afterwards
/// (see MsStoreCatalogService) — the local package only knows its name.
class XboxGame implements LibraryGame {
  final String packageFamilyName;

  /// Application id inside the package — together with
  /// [packageFamilyName] it forms the AUMID Windows launches.
  final String appId;
  @override
  String name;

  /// True on the Windows device that actually has it installed; false for
  /// copies pulled from Cloud-Sync on another device.
  final bool isInstalled;

  String? productId;
  String? posterUrl;
  String? heroUrl;
  String? description;
  String? developer;

  XboxGame({
    required this.packageFamilyName,
    required this.appId,
    required this.name,
    this.isInstalled = true,
    this.productId,
    this.posterUrl,
    this.heroUrl,
    this.description,
    this.developer,
  });

  @override
  String get id => 'xbox:$packageFamilyName';

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

  @override
  bool get hasBeenPlayed => false;

  @override
  DateTime? get lastPlayed => null;

  @override
  String get primaryActionLabel =>
      isInstalled ? 'Spiel starten' : 'Im Store öffnen';

  /// Not launchable as a URL — packaged apps start via their AUMID, see
  /// [launch]. Used as the fallback target where only a URL fits.
  @override
  String get primaryActionUrl => storePageUrl;

  /// Starts the installed game the same way the Start menu does.
  Future<bool> launch() async {
    if (!Platform.isWindows || !isInstalled) return false;
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
    'appId': appId,
    'name': name,
    'productId': productId,
    'posterUrl': posterUrl,
    'heroUrl': heroUrl,
    'description': description,
    'developer': developer,
  };

  factory XboxGame.fromSyncJson(Map<String, dynamic> json) => XboxGame(
    packageFamilyName: json['packageFamilyName'] as String,
    appId: (json['appId'] as String?) ?? 'Game',
    name: json['name'] as String,
    isInstalled: false,
    productId: json['productId'] as String?,
    posterUrl: json['posterUrl'] as String?,
    heroUrl: json['heroUrl'] as String?,
    description: json['description'] as String?,
    developer: json['developer'] as String?,
  );
}
