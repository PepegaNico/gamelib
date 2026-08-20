import 'package:flutter/foundation.dart';

import '../../core/itad/itad_api_service.dart';
import '../../core/itad/itad_credentials_store.dart';
import '../../core/itad/itad_default_key.dart';
import '../../core/itad/itad_models.dart';
import '../../core/locale/region.dart';
import '../../core/steam/steam_account.dart';
import '../../core/steam/steam_store_api_service.dart';
import '../../core/steam/steam_wishlist_api_service.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../../core/wishlist/wishlist_store.dart';

class WishlistState extends ChangeNotifier {
  WishlistState({
    ItadApiService? apiService,
    ItadCredentialsStore? credentialsStore,
    WishlistStore? store,
    SteamWishlistApiService? steamWishlistApi,
    SteamStoreApiService? steamStoreApi,
  }) : _apiService = apiService ?? ItadApiService(),
       _credentialsStore = credentialsStore ?? ItadCredentialsStore.instance,
       _store = store ?? WishlistStore(),
       _steamWishlistApi = steamWishlistApi ?? SteamWishlistApiService(),
       _steamStoreApi = steamStoreApi ?? SteamStoreApiService();

  final ItadApiService _apiService;
  final ItadCredentialsStore _credentialsStore;
  final WishlistStore _store;
  final SteamWishlistApiService _steamWishlistApi;
  final SteamStoreApiService _steamStoreApi;

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

  /// Whether the user personally connected their own ITAD key (drives the
  /// "connected"/disconnect UI in Settings, and what Cloud-Sync/QR-export
  /// actually shares with other devices — the shared build-time default
  /// below is never synced, every device already has it built in).
  bool get hasOwnKey => apiKey != null && apiKey!.isNotEmpty;

  /// The key actually used for ITAD calls: the user's own if they connected
  /// one, otherwise the shared key baked in at build time (if any) — see
  /// ItadDefaultKey. Null when neither is available.
  String? get effectiveApiKey {
    if (hasOwnKey) return apiKey;
    return ItadDefaultKey.isSet ? ItadDefaultKey.value : null;
  }

  /// Whether ITAD calls (price comparison, search) can be made at all,
  /// through either the user's own key or the shared default.
  bool get isConnected => effectiveApiKey != null;

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

  /// Connects the user's own IsThereAnyDeal key. Validates it against the
  /// API first — previously an invalid key was accepted silently and only
  /// surfaced as a "key ungültig" error much later during a Steam import
  /// (or never, if the wishlist was still empty at connect time, since
  /// refreshPrices skips empty wishlists). Returns an error message on an
  /// invalid key, or null once it's actually confirmed to work.
  Future<String?> connect(String key) async {
    try {
      await _apiService.lookupByTitle(key, 'Portal');
    } on ItadApiException catch (e) {
      return e.message;
    } catch (_) {
      // A network hiccup during validation shouldn't block connecting — the
      // key itself might be fine, it'll be retried on the next refresh.
    }

    apiKey = key;
    await _credentialsStore.setApiKey(key);
    notifyListeners();
    if (entries.isNotEmpty) await refreshPrices();
    return null;
  }

  Future<void> disconnect() async {
    await _credentialsStore.clearApiKey();
    apiKey = null;
    priceCache = {};
    notifyListeners();
    // The shared default key (if any) may still cover this — keep prices
    // showing rather than blanking them out.
    if (isConnected && entries.isNotEmpty) await refreshPrices();
  }

  Future<List<ItadGameMatch>> search(String title) async {
    if (!isConnected) return [];
    return _apiService.search(effectiveApiKey!, title);
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

  /// Drops wishlist entries for games the user now owns on Steam — a
  /// wishlist entry that's already been bought has no further reason to
  /// be tracked. Only Steam-imported entries (they carry a steamAppId) can
  /// be matched this way; manually-added ITAD entries are left alone.
  Future<void> removeOwned(Set<int> ownedSteamAppIds) async {
    if (ownedSteamAppIds.isEmpty || entries.isEmpty) return;
    final remaining = entries
        .where(
          (e) => e.steamAppId == null || !ownedSteamAppIds.contains(e.steamAppId),
        )
        .toList();
    if (remaining.length == entries.length) return;
    entries = remaining;
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
            steamAppId: e.steamAppId,
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
  /// isn't already tracked here. Doesn't require IsThereAnyDeal — when it's
  /// available (own key or shared default), each Steam appid is matched to
  /// its ITAD entry for cross-store price comparison (Epic/GOG/etc., not
  /// just Steam); when it's not (or it stops working partway through, e.g.
  /// an invalid key), games are added with just their Steam name/appid
  /// instead of being blocked entirely. Returns an error message on
  /// failure, or null on success (even if zero new games were found) — a
  /// null return with entries added but no price data means ITAD wasn't
  /// available for some or all of them.
  Future<String?> importFromSteam(List<SteamAccount> accounts) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final appIds = <int>{};
      final diagnostics = <String>[];
      for (final account in accounts) {
        final result = await _steamWishlistApi.getWishlistAppIds(
          steamId: account.steamId,
          apiKey: account.apiKey,
        );
        appIds.addAll(result.appIds);
        if (result.error != null) {
          diagnostics.add('${account.personaName}: ${result.error}');
        }
      }

      if (appIds.isEmpty) {
        return diagnostics.isNotEmpty
            ? 'Keine Steam-Wishlist-Spiele gefunden — ${diagnostics.join(' / ')}'
            : 'Keine Spiele auf deiner Steam-Wishlist gefunden.';
      }

      steamImportTotal = appIds.length;
      steamImportDone = 0;
      notifyListeners();

      var added = 0;
      var upgraded = false;
      // Starts true only if ITAD is actually available; flips to false for
      // the rest of the run the moment a lookup fails (e.g. invalid key) so
      // one broken ITAD connection doesn't abort the whole import.
      var itadAvailable = isConnected;
      String? itadWarning;

      for (final appId in appIds) {
        steamImportDone++;
        if (steamImportDone % 5 == 0) notifyListeners();

        final syntheticId = 'steam:$appId';

        if (itadAvailable) {
          ItadGameMatch? match;
          try {
            match = await _apiService.lookupBySteamAppId(
              effectiveApiKey!,
              appId,
            );
          } on ItadApiException catch (e) {
            // The key itself is confirmed invalid — no point retrying it for
            // the rest of this run, fall through to the Steam-only path.
            itadAvailable = false;
            itadWarning =
                'IsThereAnyDeal-Preisvergleich nicht verfügbar ($e) — '
                'restliche Spiele wurden ohne Preise importiert.';
          } catch (e) {
            // A transient failure (network blip, timeout) for just this one
            // game — leave ITAD enabled for the rest and simply retry this
            // one on the next import pass instead of downgrading it.
            continue;
          }

          if (itadAvailable) {
            final resolved = match;
            if (resolved != null) {
              final realIndex = entries.indexWhere(
                (e) => e.itadGameId == resolved.id,
              );
              final syntheticIndex = entries.indexWhere(
                (e) => e.itadGameId == syntheticId,
              );
              if (realIndex != -1) {
                // Already tracked under its real ITAD id — just backfill the
                // cover image if an older import didn't set it, and drop any
                // leftover placeholder duplicate from before ITAD worked.
                if (entries[realIndex].steamAppId == null) {
                  entries = [
                    for (final e in entries)
                      if (e.itadGameId == resolved.id)
                        e.copyWith(steamAppId: appId)
                      else
                        e,
                  ];
                  upgraded = true;
                }
                if (syntheticIndex != -1) {
                  entries = entries
                      .where((e) => e.itadGameId != syntheticId)
                      .toList();
                  upgraded = true;
                }
              } else if (syntheticIndex != -1) {
                // Placeholder entry from a time ITAD wasn't available — now
                // that it is, upgrade it to the real ITAD entry so images
                // and price comparison start working for it.
                entries = [
                  for (final e in entries)
                    if (e.itadGameId == syntheticId)
                      e.copyWith(
                        itadGameId: resolved.id,
                        title: resolved.title,
                        slug: resolved.slug,
                        steamAppId: appId,
                      )
                    else
                      e,
                ];
                upgraded = true;
              } else {
                entries = [
                  ...entries,
                  WishlistEntry(
                    itadGameId: resolved.id,
                    title: resolved.title,
                    slug: resolved.slug,
                    targetPriceAmount: null,
                    addedAt: DateTime.now(),
                    steamAppId: appId,
                  ),
                ];
                added++;
              }
            }
            continue;
          }
        }

        final existingSyntheticIndex = entries.indexWhere(
          (e) => e.itadGameId == syntheticId,
        );
        if (existingSyntheticIndex != -1) {
          if (entries[existingSyntheticIndex].steamAppId == null) {
            entries = [
              for (final e in entries)
                if (e.itadGameId == syntheticId)
                  e.copyWith(steamAppId: appId)
                else
                  e,
            ];
            upgraded = true;
          }
          continue;
        }
        final details = await _steamStoreApi.getAppDetails(appId);
        entries = [
          ...entries,
          WishlistEntry(
            itadGameId: syntheticId,
            title: details?.name ?? 'Steam-App $appId',
            slug: '',
            targetPriceAmount: null,
            addedAt: DateTime.now(),
            steamAppId: appId,
          ),
        ];
        added++;
      }

      // Only a genuinely new entry is a real change worth telling Cloud-Sync
      // about — resolving an existing placeholder's id/image is just this
      // device catching up on what's already there, and bumping the sync
      // timestamp for that could make this device's copy "win" a later
      // sync purely by having refreshed first, overwriting a newer edit
      // made on another device with no actual new information.
      if (added > 0) {
        entriesUpdatedAt = await _store.saveAll(entries);
      } else if (upgraded) {
        await _store.replaceAll(entries, entriesUpdatedAt);
      }
      if ((added > 0 || upgraded) && isConnected) await refreshPrices();
      return itadWarning;
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
      await _upgradeSyntheticEntries();

      // Entries imported without ITAD available carry a synthetic
      // "steam:<appid>" id (see importFromSteam) rather than a real ITAD
      // id — pointless to send those, ITAD won't recognize them.
      final realIds = entries
          .map((e) => e.itadGameId)
          .where((id) => !id.startsWith('steam:'))
          .toList();
      if (realIds.isEmpty) return;

      // Merge into the existing cache rather than replacing it outright —
      // a rate-limited or partially-failed batch call still returns 200
      // with whatever it did manage to fetch, and overwriting the whole
      // cache with that made already-loaded prices vanish again on the
      // very next refresh for no real reason.
      final fetched = await _apiService.getPrices(
        effectiveApiKey!,
        realIds,
        country: RegionDetector.detect(),
      );
      priceCache = {...priceCache, ...fetched};
    } catch (e) {
      errorMessage = 'Preise konnten nicht geladen werden: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Resolves leftover "steam:<appid>" placeholder entries to their real
  /// ITAD id purely from their stored steamAppId — no Steam account or
  /// wishlist re-scan needed. Runs on every price refresh, so it also
  /// covers devices that never ran a full Steam import themselves (e.g.
  /// entries that arrived here via Cloud-Sync from another device where
  /// ITAD wasn't available yet, or this device simply has no Steam
  /// account connected locally — importFromSteam alone can't reach those).
  /// Caps how many placeholders get resolved per refresh — this runs right
  /// before the batch price call below, and a large wishlist full of
  /// placeholders firing off that many sequential single-game lookups
  /// first made the batch call itself far more likely to get rate-limited
  /// (which used to silently wipe the whole price cache — see
  /// refreshPrices). The rest simply get picked up on the next refresh.
  static const _maxSyntheticUpgradesPerRefresh = 15;

  Future<void> _upgradeSyntheticEntries() async {
    final pending = entries
        .where(
          (e) => e.itadGameId.startsWith('steam:') && e.steamAppId != null,
        )
        .take(_maxSyntheticUpgradesPerRefresh)
        .toList();
    if (pending.isEmpty) return;

    var changed = false;
    for (final entry in pending) {
      ItadGameMatch? match;
      try {
        match = await _apiService.lookupBySteamAppId(
          effectiveApiKey!,
          entry.steamAppId!,
        );
      } on ItadApiException {
        // Key genuinely invalid — no point retrying the rest right now.
        break;
      } catch (_) {
        // Transient failure for this one — leave it, retry next refresh.
        continue;
      }
      if (match == null) continue;

      final resolved = match;
      final realIndex = entries.indexWhere((e) => e.itadGameId == resolved.id);
      if (realIndex != -1) {
        // Already tracked under its real id too (duplicate) — drop the
        // placeholder instead of overwriting the real entry.
        entries = entries
            .where((e) => e.itadGameId != entry.itadGameId)
            .toList();
      } else {
        entries = [
          for (final e in entries)
            if (e.itadGameId == entry.itadGameId)
              e.copyWith(
                itadGameId: resolved.id,
                title: resolved.title,
                slug: resolved.slug,
              )
            else
              e,
        ];
      }
      changed = true;
    }
    // Persist locally without bumping entriesUpdatedAt — resolving a
    // placeholder to its (deterministic) real ITAD id isn't a user edit,
    // and treating it as one made whichever device happened to run this
    // last "win" the next Cloud-Sync, silently overwriting a genuinely
    // newer wishlist on another device with stale placeholder data.
    if (changed) await _store.replaceAll(entries, entriesUpdatedAt);
  }
}
