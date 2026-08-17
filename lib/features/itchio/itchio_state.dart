import 'package:flutter/foundation.dart';

import '../../core/itchio/itchio_account.dart';
import '../../core/itchio/itchio_api_service.dart';
import '../../core/itchio/itchio_credentials_store.dart';
import '../../core/itchio/itchio_game.dart';

class ItchioState extends ChangeNotifier {
  ItchioState({ItchioApiService? apiService, ItchioCredentialsStore? store})
    : _apiService = apiService ?? ItchioApiService(),
      _store = store ?? ItchioCredentialsStore.instance;

  final ItchioApiService _apiService;
  final ItchioCredentialsStore _store;

  List<ItchioAccount> accounts = [];
  List<ItchioGame> games = [];
  bool isLoading = false;
  String? errorMessage;

  bool get isConnected => accounts.isNotEmpty;

  Future<void> restore() async {
    accounts = await _store.getAccounts();
    notifyListeners();
    if (accounts.isEmpty) return;

    // A migrated legacy account has no cached username yet — fill it in.
    if (accounts.any((a) => a.username.isEmpty)) {
      accounts = await Future.wait(
        accounts.map((a) async {
          if (a.username.isNotEmpty) return a;
          try {
            final name = await _apiService.getUsername(a.apiKey);
            return ItchioAccount(apiKey: a.apiKey, username: name);
          } catch (_) {
            return a;
          }
        }),
      );
      await _store.saveAccounts(accounts);
    }
    await refresh();
  }

  /// Connects and adds another itch.io account, merging its owned games into
  /// the existing library. Returns an error message on failure, or null on
  /// success.
  Future<String?> addAccount(String key) async {
    if (accounts.any((a) => a.apiKey == key)) {
      return 'Dieser API-Key ist bereits verbunden.';
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final name = await _apiService.getUsername(key);
      accounts = [...accounts, ItchioAccount(apiKey: key, username: name)];
      await _store.saveAccounts(accounts);
      await _loadGames();
      return null;
    } catch (e) {
      errorMessage = 'Verbindung fehlgeschlagen: $e';
      return errorMessage;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeAccount(String apiKey) async {
    accounts = accounts.where((a) => a.apiKey != apiKey).toList();
    await _store.saveAccounts(accounts);
    await _loadGames();
  }

  Future<void> refresh() async {
    if (!isConnected) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _loadGames();
    } catch (e) {
      errorMessage = 'Bibliothek konnte nicht geladen werden: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches owned games from every connected account and merges them,
  /// keeping one entry per game.
  Future<void> _loadGames() async {
    if (accounts.isEmpty) {
      games = [];
      notifyListeners();
      return;
    }

    final perAccount = await Future.wait(
      accounts.map((a) async {
        try {
          return await _apiService.getOwnedGames(a.apiKey);
        } catch (_) {
          return <ItchioGame>[];
        }
      }),
    );

    final merged = <int, ItchioGame>{};
    for (final accountGames in perAccount) {
      for (final game in accountGames) {
        merged[game.gameId] = game;
      }
    }
    games = merged.values.toList();
    notifyListeners();
  }
}
