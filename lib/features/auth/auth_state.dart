import 'package:flutter/foundation.dart';

import '../../core/steam/steam_account.dart';
import '../../core/steam/steam_credentials_store.dart';
import '../../core/steam/steam_openid_service.dart';
import '../../core/steam/steam_web_api_service.dart';

enum AuthStatus { unknown, needsApiKey, needsLogin, signedIn }

/// Manages every connected Steam account. The very first account still goes
/// through the classic "enter API key → sign in with Steam" onboarding
/// gate (driven by [status]); once at least one account is connected,
/// further accounts are added in-place via [addAccount] from Settings
/// without ever touching [status] again.
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
  List<SteamAccount> accounts = [];
  String? errorMessage;
  bool isSigningIn = false;

  String? _pendingApiKey;

  SteamAccount? get primaryAccount => accounts.isEmpty ? null : accounts.first;

  // Convenience accessors used by screens that only care about "the" Steam
  // account (friends list, library header) — they resolve to the primary
  // (first-connected) account once signed in.
  String? get apiKey => primaryAccount?.apiKey ?? _pendingApiKey;
  String? get steamId => primaryAccount?.steamId;
  String? get personaName => primaryAccount?.personaName;
  String? get avatarUrl => primaryAccount?.avatarUrl;

  Future<void> restore() async {
    accounts = await _store.getAccounts();
    status = accounts.isEmpty ? AuthStatus.needsApiKey : AuthStatus.signedIn;
    notifyListeners();
  }

  /// Step 1 of the first-account onboarding gate: stash the API key and
  /// move on to the "sign in with Steam" screen.
  Future<void> saveApiKey(String key) async {
    _pendingApiKey = key;
    status = AuthStatus.needsLogin;
    notifyListeners();
  }

  /// Step 2 of the first-account onboarding gate, called from LoginScreen.
  Future<void> signInWithSteam() async {
    if (_pendingApiKey == null || _pendingApiKey!.isEmpty) {
      status = AuthStatus.needsApiKey;
      notifyListeners();
      return;
    }

    final error = await _performSignIn(_pendingApiKey!);
    if (error == null) {
      _pendingApiKey = null;
      status = AuthStatus.signedIn;
    }
    notifyListeners();
  }

  /// Adds an additional Steam account once already signed in (used by the
  /// Settings screen). Returns an error message on failure, or null on
  /// success — [status] is left untouched since the app is already past
  /// the onboarding gate.
  Future<String?> addAccount(String apiKey) async {
    final error = await _performSignIn(apiKey);
    notifyListeners();
    return error;
  }

  /// Adds an account whose SteamID64 is already known (from a QR-code
  /// transfer from another device) — skips the OpenID browser round-trip
  /// entirely, just re-validates the key/id pair against Steam. Also works
  /// before any account is connected yet, letting a fresh device skip the
  /// normal onboarding gate.
  Future<String?> importAccount({
    required String steamId,
    required String apiKey,
  }) async {
    if (accounts.any((a) => a.steamId == steamId)) {
      return null;
    }

    try {
      final summary = await _webApiService.getPlayerSummary(
        apiKey: apiKey,
        steamId: steamId,
      );
      accounts = [
        ...accounts,
        SteamAccount(
          steamId: steamId,
          apiKey: apiKey,
          personaName: summary.personaName,
          avatarUrl: summary.avatarUrl,
        ),
      ];
      await _store.saveAccounts(accounts);
      status = AuthStatus.signedIn;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Import fehlgeschlagen: $e';
    }
  }

  Future<String?> _performSignIn(String apiKey) async {
    isSigningIn = true;
    errorMessage = null;
    notifyListeners();

    try {
      final id = await _openIdService.signIn();
      if (id == null) {
        errorMessage = 'Anmeldung wurde abgebrochen oder ist fehlgeschlagen.';
        return errorMessage;
      }
      if (accounts.any((a) => a.steamId == id)) {
        errorMessage = 'Dieser Steam-Account ist bereits verbunden.';
        return errorMessage;
      }

      final summary = await _webApiService.getPlayerSummary(
        apiKey: apiKey,
        steamId: id,
      );
      final account = SteamAccount(
        steamId: id,
        apiKey: apiKey,
        personaName: summary.personaName,
        avatarUrl: summary.avatarUrl,
      );
      accounts = [...accounts, account];
      await _store.saveAccounts(accounts);
      return null;
    } catch (e) {
      errorMessage = 'Anmeldung fehlgeschlagen: $e';
      return errorMessage;
    } finally {
      isSigningIn = false;
    }
  }

  /// Cancels the pending "enter API key" onboarding step (before any
  /// account is connected) so the user can re-enter a different key.
  Future<void> removeApiKey() async {
    _pendingApiKey = null;
    status = AuthStatus.needsApiKey;
    notifyListeners();
  }

  Future<void> removeAccount(String steamId) async {
    accounts = accounts.where((a) => a.steamId != steamId).toList();
    await _store.saveAccounts(accounts);
    if (accounts.isEmpty) {
      status = AuthStatus.needsApiKey;
    }
    notifyListeners();
  }

  /// Disconnects every Steam account (the AppBar "Abmelden" action).
  Future<void> signOut() async {
    accounts = [];
    _pendingApiKey = null;
    await _store.saveAccounts([]);
    status = AuthStatus.needsApiKey;
    notifyListeners();
  }
}
