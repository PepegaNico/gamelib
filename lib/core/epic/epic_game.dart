import '../models/game_platform.dart';
import '../models/library_game.dart';
import 'epic_store_listing.dart';

/// Neither the local Epic manifest files nor Legendary's `list --json`
/// expose a real store description, cover image or product page reliably.
/// [applyStoreListing] fills those in (see
/// [LibraryState.prefetchEpicDetails] and [EpicGameDetailsScreen]) by
/// searching Epic's public store catalog for the exact title — until then
/// the UI falls back to a styled placeholder card and generic search link.
class EpicGame implements LibraryGame {
  final String appName;
  @override
  final String name;
  final String? namespace;
  final String? catalogItemId;

  /// True when this entry came from `legendary list`, which knows the
  /// user's whole purchased library (not just what's installed) but can
  /// only be launched via the legendary CLI itself, not the official
  /// Epic launcher protocol.
  final bool viaLegendary;

  /// True once matched against a local Epic Games Launcher manifest —
  /// meaning the official `com.epicgames.launcher://` protocol will work.
  /// Legendary tracks its own separate installs and knows nothing about
  /// games installed through the real launcher, so `legendary launch`
  /// fails for those even though they're perfectly playable — this flag
  /// (plus [installedAppName], the manifest's own AppName) is what lets
  /// the app prefer the reliable native launch when possible. See
  /// [EpicState.refresh].
  bool isInstalled;
  String? installedAppName;

  String? resolvedImageUrl;
  String? resolvedDescription;
  String? resolvedDeveloper;
  List<String> resolvedCategories = [];
  String? resolvedProductSlug;
  bool storeDetailsFetched = false;

  EpicGame({
    required this.appName,
    required this.name,
    required this.namespace,
    required this.catalogItemId,
    this.viaLegendary = false,
    this.isInstalled = false,
    this.installedAppName,
  });

  factory EpicGame.fromManifestJson(Map<String, dynamic> json) {
    final appName = (json['AppName'] as String?) ?? '';
    return EpicGame(
      appName: appName,
      name: (json['DisplayName'] as String?) ?? 'Unbekanntes Spiel',
      namespace: json['CatalogNamespace'] as String?,
      catalogItemId: json['CatalogItemId'] as String?,
      isInstalled: true,
      installedAppName: appName,
    );
  }

  /// `legendary list --json` nests namespace/catalog-id/images under a
  /// `metadata` object (the raw Epic catalog entry) rather than at the top
  /// level — `app_name`/`app_title` are the only fields legendary promotes
  /// itself. The cover image is already right here, so no extra API call
  /// is needed for that (unlike manifest-only games). Legendary's own
  /// `description` field just repeats the title though, so richer text
  /// still comes from [applyStoreListing].
  factory EpicGame.fromLegendaryJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final images =
        (metadata['keyImages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final preferredImage = images.firstWhere(
      (img) => (img['type'] as String?) == 'DieselGameBox',
      orElse: () => images.isNotEmpty ? images.first : <String, dynamic>{},
    );
    final categories =
        (metadata['categories'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((c) => c['path'] as String? ?? '')
            .where((p) => p.isNotEmpty)
            .toList() ??
        [];

    return EpicGame(
        appName: (json['app_name'] as String?) ?? '',
        name:
            (json['app_title'] as String?) ??
            (metadata['title'] as String?) ??
            'Unbekanntes Spiel',
        namespace: metadata['namespace'] as String?,
        catalogItemId: metadata['id'] as String?,
        viaLegendary: true,
      )
      ..resolvedImageUrl = preferredImage['url'] as String?
      ..resolvedDeveloper = metadata['developer'] as String?
      ..resolvedCategories = categories;
  }

  /// Merges in richer store data found via [EpicStoreApiService.findByTitle].
  /// Only overwrites the cover image if one isn't already known, since a
  /// title-search match is fuzzier than Legendary's own exact metadata.
  void applyStoreListing(EpicStoreListing listing) {
    resolvedImageUrl ??= listing.imageUrl;
    resolvedDescription = listing.description;
    if (listing.developerName != null) {
      resolvedDeveloper = listing.developerName;
    }
    if (listing.categoryPaths.isNotEmpty) {
      resolvedCategories = listing.categoryPaths;
    }
    if (listing.productSlug.isNotEmpty) {
      resolvedProductSlug = listing.productSlug;
    }
    storeDetailsFetched = true;
  }

  @override
  String get id => 'epic:$appName';

  @override
  GamePlatform get platform => GamePlatform.epic;

  @override
  String get headerImageUrl => resolvedImageUrl ?? '';

  @override
  String get storePageUrl => resolvedProductSlug != null
      ? 'https://store.epicgames.com/en-US/p/$resolvedProductSlug'
      : 'https://store.epicgames.com/en-US/browse?q=${Uri.encodeComponent(name)}';

  @override
  bool get hasPlaytimeData => false;

  @override
  double get playtimeForeverHours => 0;

  @override
  bool get hasBeenPlayed => false;

  @override
  DateTime? get lastPlayed => null;

  @override
  String get primaryActionLabel => 'Spiel starten';

  @override
  String get primaryActionUrl {
    if (isInstalled &&
        namespace != null &&
        namespace!.isNotEmpty &&
        catalogItemId != null &&
        catalogItemId!.isNotEmpty &&
        installedAppName != null) {
      return 'com.epicgames.launcher://apps/$namespace%3A$catalogItemId%3A$installedAppName?action=launch&silent=true';
    }
    return storePageUrl;
  }
}
