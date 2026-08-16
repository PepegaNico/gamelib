import 'package:flutter/foundation.dart';

import '../../core/steam/steam_credentials_store.dart';
import '../../core/steam/steam_game.dart';
import '../../core/steam/steam_news_item.dart';
import '../../core/steam/steam_web_api_service.dart';

/// Polls Steam's per-game news feed for the whole library and surfaces
/// items posted since the user last opened the updates list.
class UpdatesState extends ChangeNotifier {
  UpdatesState({
    SteamWebApiService? webApiService,
    SteamCredentialsStore? store,
  }) : _webApiService = webApiService ?? SteamWebApiService(),
       _store = store ?? SteamCredentialsStore.instance;

  final SteamWebApiService _webApiService;
  final SteamCredentialsStore _store;

  static const _concurrency = 6;
  static const _lookback = Duration(days: 30);

  List<SteamNewsItem> recentItems = [];
  int unreadCount = 0;
  bool isLoading = false;
  DateTime? _lastChecked;

  Future<void> checkForUpdates(List<SteamGame> games) async {
    if (games.isEmpty || isLoading) return;
    isLoading = true;
    notifyListeners();

    _lastChecked ??=
        await _store.getLastNewsCheck() ?? DateTime.now().subtract(_lookback);
    final cutoff = DateTime.now().subtract(_lookback);

    final items = <SteamNewsItem>[];
    for (var i = 0; i < games.length; i += _concurrency) {
      final batch = games.sublist(i, (i + _concurrency).clamp(0, games.length));
      final results = await Future.wait(
        batch.map(
          (g) => _webApiService.getNewsForApp(
            appId: g.appId,
            gameName: g.name,
            count: 3,
          ),
        ),
      );
      for (final gameItems in results) {
        items.addAll(gameItems.where((item) => item.date.isAfter(cutoff)));
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    recentItems = items;
    unreadCount = items
        .where((item) => item.date.isAfter(_lastChecked!))
        .length;
    isLoading = false;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    _lastChecked = now;
    unreadCount = 0;
    await _store.setLastNewsCheck(now);
    notifyListeners();
  }
}
