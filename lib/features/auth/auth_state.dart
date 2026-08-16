import 'package:flutter/foundation.dart';

import '../../core/steam/steam_credentials_store.dart';
import '../../core/steam/steam_openid_service.dart';
import '../../core/steam/steam_web_api_service.dart';

enum AuthStatus { unknown, needsApiKey, needsLogin, signedIn }

class AuthState extends ChangeNotifier {
  AuthState({
    SteamOpenIdService? openIdService,
    SteamWebApiService? webApiService,
    SteamCredentialsStore? store,
  }) : _openIdService = openIdService ?? SteamOpenIdService(),
       _webApiService = webApiService ?? SteamWebApiService(),
       _store = store ?? SteamCredentialsStore.instance;

  final SteamOpenIdService _openIdService;
  final SteamWebApiService _webApiService;
  final SteamCredentialsStore _store;

  AuthStatus status = AuthStatus.unknown;
  String? apiKey;
  String? steamId;
  String? personaName;
  String? avatarUrl;
  String? errorMessage;
  bool isSigningIn = false;

  Future<void> restore() async {
    apiKey = await _store.getApiKey();
    steamId = await _store.getSteamId();
    personaName = await _store.getPersonaName();
    avatarUrl = await _store.getAvatarUrl();

    if (apiKey == null || apiKey!.isEmpty) {
      status = AuthStatus.needsApiKey;
    } else if (steamId == null || steamId!.isEmpty) {
      status = AuthStatus.needsLogin;
    } else {
      status = AuthStatus.signedIn;
    }
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    await _store.setApiKey(key);
    apiKey = key;
    status = steamId == null ? AuthStatus.needsLogin : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signInWithSteam() async {
    if (apiKey == null || apiKey!.isEmpty) {
      status = AuthStatus.needsApiKey;
      notifyListeners();
      return;
    }

    isSigningIn = true;
    errorMessage = null;
    notifyListeners();

    try {
      final id = await _openIdService.signIn();
      if (id == null) {
        errorMessage = 'Anmeldung wurde abgebrochen oder ist fehlgeschlagen.';
        return;
      }

      steamId = id;
      await _store.setSteamId(id);

      final summary = await _webApiService.getPlayerSummary(
        apiKey: apiKey!,
        steamId: id,
      );
      personaName = summary.personaName;
      avatarUrl = summary.avatarUrl;
      await _store.setPersonaName(summary.personaName);
      await _store.setAvatarUrl(summary.avatarUrl);

      status = AuthStatus.signedIn;
    } catch (e) {
      errorMessage = 'Anmeldung fehlgeschlagen: $e';
    } finally {
      isSigningIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _store.clearLogin();
    steamId = null;
    personaName = null;
    avatarUrl = null;
    status = AuthStatus.needsLogin;
    notifyListeners();
  }

  Future<void> removeApiKey() async {
    await _store.clearApiKey();
    await signOut();
    apiKey = null;
    status = AuthStatus.needsApiKey;
    notifyListeners();
  }
}
