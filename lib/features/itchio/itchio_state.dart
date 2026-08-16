import 'package:flutter/foundation.dart';

import '../../core/itchio/itchio_api_service.dart';
import '../../core/itchio/itchio_credentials_store.dart';
import '../../core/itchio/itchio_game.dart';

class ItchioState extends ChangeNotifier {
  ItchioState({ItchioApiService? apiService, ItchioCredentialsStore? store})
    : _apiService = apiService ?? ItchioApiService(),
      _store = store ?? ItchioCredentialsStore.instance;

  final ItchioApiService _apiService;
  final ItchioCredentialsStore _store;

  String? apiKey;
  String? username;
  List<ItchioGame> games = [];
  bool isLoading = false;
  String? errorMessage;

  bool get isConnected => apiKey != null && apiKey!.isNotEmpty;

  /// Only restores the stored key — fetching games is left to whoever first
  /// needs them (the library screen), so there's a single place that owns
  /// "when do we hit the network".
  Future<void> restore() async {
    apiKey = await _store.getApiKey();
    notifyListeners();
  }

  Future<void> connect(String key) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final name = await _apiService.getUsername(key);
      final ownedGames = await _apiService.getOwnedGames(key);
      apiKey = key;
      username = name;
      games = ownedGames;
      await _store.setApiKey(key);
    } catch (e) {
      errorMessage = 'Verbindung fehlgeschlagen: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!isConnected) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      username = await _apiService.getUsername(apiKey!);
      games = await _apiService.getOwnedGames(apiKey!);
    } catch (e) {
      errorMessage = 'Bibliothek konnte nicht geladen werden: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _store.clearApiKey();
    apiKey = null;
    username = null;
    games = [];
    errorMessage = null;
    notifyListeners();
  }
}
