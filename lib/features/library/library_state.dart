import 'package:flutter/foundation.dart';

import '../../core/epic/epic_game.dart';
import '../../core/epic/epic_store_api_service.dart';
import '../../core/itchio/itchio_game.dart';
import '../../core/models/library_game.dart';
import '../../core/steam/steam_account.dart';
import '../../core/steam/steam_app_details.dart';
import '../../core/steam/steam_game.dart';
import '../../core/steam/steam_store_api_service.dart';
import '../../core/steam/steam_web_api_service.dart';

class LibraryState extends ChangeNotifier {
  LibraryState({
    SteamWebApiService? webApiService,
    SteamStoreApiService? storeApiService,
    EpicStoreApiService? epicStoreApiService,
  }) : _webApiService = webApiService ?? SteamWebApiService(),
       _storeApiService = storeApiService ?? SteamStoreApiService(),
       _epicStoreApiService = epicStoreApiService ?? EpicStoreApiService();

  final SteamWebApiService _webApiService;
  final SteamStoreApiService _storeApiService;
  final EpicStoreApiService _epicStoreApiService;

  static const _prefetchConcurrency = 8;

  List<SteamGame> _steamGames = [];
  List<ItchioGame> _itchioGames = [];
  List<EpicGame> _epicGames = [];

  List<LibraryGame> get games => [
    ..._steamGames,
    ..._itchioGames,
    ..._epicGames,
  ];
  List<SteamGame> get steamGames => _steamGames;

  bool isLoading = false;
  String? errorMessage;

  /// Populated progressively in the background by [prefetchAppDetails] so
  /// the library-wide controller-support/language filters can work without
  /// blocking the initial load. Steam-only — itch.io has no equivalent data.
  final Map<int, SteamAppDetails> appDetailsCache = {};
  bool isPrefetchingDetails = false;
  int prefetchedCount = 0;

  /// Loads and merges owned games from every connected Steam account. A game
  /// owned on more than one account is shown once, keeping the copy with the
  /// most playtime (the account it's actually played on) so achievements
  /// and launch data resolve to the right account.
  Future<void> load({required List<SteamAccount> accounts}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      var anySucceeded = false;
      final perAccount = await Future.wait(
        accounts.map((account) async {
          try {
            final games = await _webApiService.getOwnedGames(
              apiKey: account.apiKey,
              steamId: account.steamId,
            );
            anySucceeded = true;
            return games;
          } catch (_) {
            return <SteamGame>[];
          }
        }),
      );

      final merged = <int, SteamGame>{};
      for (final accountGames in perAccount) {
        for (final game in accountGames) {
          final existing = merged[game.appId];
          if (existing == null ||
              game.playtimeForeverMinutes > existing.playtimeForeverMinutes) {
            merged[game.appId] = game;
          }
        }
      }
      _steamGames = merged.values.toList()
        ..sort(
          (a, b) => b.playtimeForeverMinutes.compareTo(a.playtimeForeverMinutes),
        );

      if (!anySucceeded && accounts.isNotEmpty) {
        errorMessage = 'Bibliothek konnte nicht geladen werden.';
      } else if (games.isEmpty) {
        errorMessage =
            'Keine Spiele gefunden. Prüfe, ob dein Steam-Profil und deine '
            'Spieledetails auf "Öffentlich" gestellt sind (Steam-Profil → '
            'Datenschutzeinstellungen).';
      }
    } catch (e) {
      errorMessage = 'Bibliothek konnte nicht geladen werden: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setItchioGames(List<ItchioGame> games) {
    _itchioGames = games;
    if (errorMessage != null && this.games.isNotEmpty) errorMessage = null;
    notifyListeners();
  }

  void setEpicGames(List<EpicGame> games) {
    _epicGames = games;
    if (errorMessage != null && this.games.isNotEmpty) errorMessage = null;
    notifyListeners();
  }

  Future<void> prefetchAppDetails() async {
    if (isPrefetchingDetails || _steamGames.isEmpty) return;
    isPrefetchingDetails = true;
    prefetchedCount = 0;
    notifyListeners();

    for (var i = 0; i < _steamGames.length; i += _prefetchConcurrency) {
      final batch = _steamGames.sublist(
        i,
        (i + _prefetchConcurrency).clamp(0, _steamGames.length),
      );
      final results = await Future.wait(
        batch.map((g) => _storeApiService.getAppDetails(g.appId)),
      );
      for (var j = 0; j < batch.length; j++) {
        final details = results[j];
        if (details != null) appDetailsCache[batch[j].appId] = details;
      }
      prefetchedCount += batch.length;
      notifyListeners();
    }

    isPrefetchingDetails = false;
    notifyListeners();
  }

  bool isPrefetchingEpicDetails = false;
  int epicPrefetchedCount = 0;

  /// Looks each Epic game up by title on the public store catalog to fill
  /// in cover art, description, developer and a real store link — none of
  /// which the local manifest or Legendary's own metadata reliably provide
  /// (see [EpicGame.applyStoreListing]).
  Future<void> prefetchEpicDetails() async {
    final pending = _epicGames.where((g) => !g.storeDetailsFetched).toList();
    if (isPrefetchingEpicDetails || pending.isEmpty) return;
    isPrefetchingEpicDetails = true;
    epicPrefetchedCount = 0;
    notifyListeners();

    for (var i = 0; i < pending.length; i += _prefetchConcurrency) {
      final batch = pending.sublist(
        i,
        (i + _prefetchConcurrency).clamp(0, pending.length),
      );
      final results = await Future.wait(
        batch.map((g) => _epicStoreApiService.findByTitle(g.name)),
      );
      for (var j = 0; j < batch.length; j++) {
        final listing = results[j];
        if (listing != null) {
          batch[j].applyStoreListing(listing);
        } else {
          batch[j].storeDetailsFetched = true;
        }
      }
      epicPrefetchedCount += batch.length;
      notifyListeners();
    }

    isPrefetchingEpicDetails = false;
    notifyListeners();
  }
}
