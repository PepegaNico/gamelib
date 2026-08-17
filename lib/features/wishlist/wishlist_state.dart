import 'package:flutter/foundation.dart';

import '../../core/itad/itad_api_service.dart';
import '../../core/itad/itad_credentials_store.dart';
import '../../core/itad/itad_models.dart';
import '../../core/steam/steam_account.dart';
import '../../core/steam/steam_wishlist_api_service.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../../core/wishlist/wishlist_store.dart';

class WishlistState extends ChangeNotifier {
  WishlistState({
    ItadApiService? apiService,
    ItadCredentialsStore? credentialsStore,
    WishlistStore? store,
    SteamWishlistApiService? steamWishlistApi,
  }) : _apiService = apiService ?? ItadApiService(),
       _credentialsStore = credentialsStore ?? ItadCredentialsStore.instance,
       _store = store ?? WishlistStore(),
       _steamWishlistApi = steamWishlistApi ?? SteamWishlistApiService();

  final ItadApiService _apiService;
  final ItadCredentialsStore _credentialsStore;
  final WishlistStore _store;
  final SteamWishlistApiService _steamWishlistApi;

  /// Set by [importFromSteam] while it works through (potentially many)
  /// Steam wishlist games one lookup at a time, so the UI can show progress.
  int steamImportTotal = 0;
  int steamImportDone = 0;

  String? apiKey;
  List<WishlistEntry> entries = [];

  /// When [entries] last changed locally — compared against the Cloud-Sync
  /// copy's own timestamp to decide which side is newer (see
  /// SyncState.sync). Starts at the epoch, meaning "never touched here".
  DateTime entriesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, ItadPriceInfo> priceCache = {};
  bool isLoading = false;
  String? errorMessage;

  bool get isConnected => apiKey != null && apiKey!.isNotEmpty;

  /// Entries whose best current price has dropped to or below the target
  /// the user set — this is the whole "price alert" mechanism, checked
  /// whenever prices are refreshed rather than via any kind of push.
  List<WishlistEntry> get alertedEntries => entries.where((e) {
    if (e.targetPriceAmount == null) return false;
    final best = priceCache[e.itadGameId]?.bestDeal;
    return best != null && best.price.amount <= e.targetPriceAmount!;
  }).toList();

  Future<void> restore() async {
    apiKey = await _credentialsStore.getApiKey();
    final loaded = await _store.load();
    entries = loaded.entries;
    entriesUpdatedAt = loaded.updatedAt;
    notifyListeners();
    if (isConnected && entries.isNotEmpty) await refreshPrices();
  }

  Future<void> connect(String key) async {
    apiKey = key;
    await _credentialsStore.setApiKey(key);
    notifyListeners();
    if (entries.isNotEmpty) await refreshPrices();
  }

  Future<void> disconnect() async {
    await _credentialsStore.clearApiKey();
    apiKey = null;
    priceCache = {};
    notifyListeners();
  }

  Future<List<ItadGameMatch>> search(String title) async {
    if (!isConnected) return [];
    return _apiService.search(apiKey!, title);
  }

  Future<void> add(ItadGameMatch match) async {
    if (entries.any((e) => e.itadGameId == match.id)) return;
    entries = [
      ...entries,
      WishlistEntry(
        itadGameId: match.id,
        title: match.title,
        slug: match.slug,
        targetPriceAmount: null,
        addedAt: DateTime.now(),
      ),
    ];
    entriesUpdatedAt = await _store.saveAll(entries);
    notifyListeners();
    if (isConnected) await refreshPrices();
  }

  Future<void> remove(String itadGameId) async {
    entries = entries.where((e) => e.itadGameId != itadGameId).toList();
    entriesUpdatedAt = await _store.saveAll(entries);
    notifyListeners();
  }

  Future<void> setTargetPrice(String itadGameId, double? amount) async {
    entries = [
      for (final e in entries)
        if (e.itadGameId == itadGameId)
          WishlistEntry(
            itadGameId: e.itadGameId,
            title: e.title,
            slug: e.slug,
            targetPriceAmount: amount,
            addedAt: e.addedAt,
          )
        else
          e,
    ];
    entriesUpdatedAt = await _store.saveAll(entries);
    notifyListeners();
  }

  /// Adopts a wishlist snapshot pulled from another device via Cloud-Sync.
  /// Only called by SyncState once it's determined the remote copy is
  /// actually newer than this device's own (see WishlistStore.replaceAll).
  Future<void> applyRemote(
    List<WishlistEntry> remoteEntries,
    DateTime remoteUpdatedAt,
  ) async {
    entries = remoteEntries;
    entriesUpdatedAt = remoteUpdatedAt;
    await _store.replaceAll(remoteEntries, remoteUpdatedAt);
    notifyListeners();
    if (isConnected && entries.isNotEmpty) await refreshPrices();
  }

  /// Imports every game on the given Steam accounts' public wishlists that
  /// isn't already tracked here, matching each Steam appid to its
  /// IsThereAnyDeal entry (so the resulting wishlist entries get the same
  /// cross-store price comparison as anything added manually — ITAD covers
  /// Epic/GOG/etc. prices too, not just Steam). Returns an error message on
  /// failure, or null on success (even if zero new games were found).
  Future<String?> importFromSteam(List<SteamAccount> accounts) async {
    if (!isConnected) {
      return 'Erst IsThereAnyDeal in den Einstellungen verbinden.';
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final appIds = <int>{};
      for (final account in accounts) {
        appIds.addAll(
          await _steamWishlistApi.getWishlistAppIds(
            steamId: account.steamId,
            apiKey: account.apiKey,
          ),
        );
      }

      steamImportTotal = appIds.length;
      steamImportDone = 0;
      notifyListeners();

      var added = 0;
      for (final appId in appIds) {
        steamImportDone++;
        if (steamImportDone % 5 == 0) notifyListeners();

        final match = await _apiService.lookupBySteamAppId(apiKey!, appId);
        if (match == null || entries.any((e) => e.itadGameId == match.id)) {
          continue;
        }
        entries = [
          ...entries,
          WishlistEntry(
            itadGameId: match.id,
            title: match.title,
            slug: match.slug,
            targetPriceAmount: null,
            addedAt: DateTime.now(),
          ),
        ];
        added++;
      }

      entriesUpdatedAt = await _store.saveAll(entries);
      if (added > 0) await refreshPrices();
      return null;
    } catch (e) {
      errorMessage = 'Steam-Wishlist-Import fehlgeschlagen: $e';
      return errorMessage;
    } finally {
      steamImportTotal = 0;
      steamImportDone = 0;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPrices() async {
    if (!isConnected || entries.isEmpty) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      priceCache = await _apiService.getPrices(
        apiKey!,
        entries.map((e) => e.itadGameId).toList(),
      );
    } catch (e) {
      errorMessage = 'Preise konnten nicht geladen werden: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
