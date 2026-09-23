import 'package:flutter/foundation.dart';

import '../../core/playstation/playstation_game.dart';
import '../../core/playstation/psn_api_service.dart';
import '../../core/playstation/psn_credentials_store.dart';

/// The connected PlayStation account's played PS4/PS5 games. Connected
/// only from the Windows app; iOS receives the list through Cloud-Sync.
class PlaystationState extends ChangeNotifier {
  PlaystationState({PsnApiService? api, PsnCredentialsStore? store})
    : _api = api ?? PsnApiService(),
      _store = store ?? PsnCredentialsStore.instance;

  final PsnApiService _api;
  final PsnCredentialsStore _store;

  List<PlaystationGame> games = [];
  String? onlineId;
  bool isConnected = false;
  bool isLoading = false;
  String? errorMessage;

  Future<void> refresh() async {
    final refreshToken = await _store.getRefreshToken();
    if (refreshToken == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final session = await _api.refresh(refreshToken);
      await _load(session);
    } on PsnException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'PlayStation-Spiele konnten nicht geladen werden.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> connect(String npsso) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final session = await _api.signInWithNpsso(npsso.trim());
      await _load(session);
      return null;
    } on PsnException catch (e) {
      errorMessage = e.message;
      return e.message;
    } catch (_) {
      errorMessage = 'PlayStation-Anmeldung fehlgeschlagen.';
      return errorMessage;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _load(PsnSession session) async {
    await _store.saveRefreshToken(session.refreshToken);
    isConnected = true;
    onlineId = await _api.onlineId(session) ?? onlineId;
    games = await _api.playedGames(session)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    errorMessage = null;
  }

  Future<void> disconnect() async {
    await _store.clear();
    isConnected = false;
    onlineId = null;
    games = [];
    errorMessage = null;
    notifyListeners();
  }
}
