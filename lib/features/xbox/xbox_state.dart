import 'package:flutter/foundation.dart';

import '../../core/xbox/ms_store_catalog_service.dart';
import '../../core/xbox/xbox_credentials_store.dart';
import '../../core/xbox/xbox_game.dart';
import '../../core/xbox/xbox_live_config.dart';
import '../../core/xbox/xbox_live_service.dart';
import '../../core/xbox/xbox_local_scanner.dart';

/// Xbox games on this PC: locally installed Xbox app / Microsoft Store
/// games (Windows only, no login), merged with the signed-in Xbox
/// account's title history (every game played on console, PC or cloud).
class XboxState extends ChangeNotifier {
  XboxState({
    XboxLocalScanner? scanner,
    MsStoreCatalogService? catalog,
    XboxLiveService? live,
    XboxCredentialsStore? store,
  }) : _scanner = scanner ?? XboxLocalScanner(),
       _catalog = catalog ?? MsStoreCatalogService(),
       _live = live ?? XboxLiveService(),
       _store = store ?? XboxCredentialsStore.instance;

  final XboxLocalScanner _scanner;
  final MsStoreCatalogService _catalog;
  final XboxLiveService _live;
  final XboxCredentialsStore _store;

  List<XboxGame> games = [];
  bool isLoading = false;
  bool hasScanned = false;

  String? gamertag;
  String? errorMessage;

  /// Set while waiting for the user to enter [pendingCode] on microsoft.com.
  XboxDeviceCode? pendingCode;
  bool _cancelSignIn = false;

  bool get canSignIn => XboxLiveConfig.isConfigured;
  bool get isSignedIn => gamertag != null;

  int get installedCount => games.where((g) => g.isInstalled).length;

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();

    final installed = await _scanner.listInstalledGames();
    await Future.wait(installed.map(_catalog.enrich));
    final played = await _loadTitleHistory();

    games = _merge(installed, played);
    hasScanned = true;
    isLoading = false;
    notifyListeners();
  }

  /// Installed games take precedence (they can be launched) and pick up
  /// play data from the matching title-history entry; everything else
  /// from the history is added as not installed.
  List<XboxGame> _merge(List<XboxGame> installed, List<XboxGame> played) {
    final playedByPfn = {
      for (final g in played)
        if (g.packageFamilyName != null) g.packageFamilyName!: g,
    };
    final result = <XboxGame>[];
    for (final g in installed) {
      final cloud = playedByPfn.remove(g.packageFamilyName);
      result.add(cloud == null ? g : g.mergedWith(cloud));
    }
    result
      ..addAll(playedByPfn.values)
      ..addAll(played.where((g) => g.packageFamilyName == null));
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<List<XboxGame>> _loadTitleHistory() async {
    if (!canSignIn) return [];
    final refreshToken = await _store.getRefreshToken();
    if (refreshToken == null) return [];
    try {
      final session = await _live.refresh(refreshToken);
      await _store.saveRefreshToken(session.refreshToken);
      gamertag = session.gamertag;
      errorMessage = null;
      return await _live.titleHistory(session);
    } on XboxLiveException catch (e) {
      errorMessage = e.message;
      return [];
    } catch (_) {
      errorMessage = 'Xbox-Spiele konnten nicht geladen werden.';
      return [];
    }
  }

  /// Starts the Microsoft device-code sign-in: shows [pendingCode] for the
  /// user to enter on microsoft.com, waits for it, then loads the library.
  /// Returns an error message, or null on success.
  Future<String?> signIn() async {
    _cancelSignIn = false;
    errorMessage = null;
    try {
      pendingCode = await _live.startDeviceCode();
      notifyListeners();
      final session = await _live.completeDeviceCode(
        pendingCode!,
        isCancelled: () => _cancelSignIn,
      );
      await _store.saveRefreshToken(session.refreshToken);
      gamertag = session.gamertag;
      pendingCode = null;
      notifyListeners();
      await refresh();
      return null;
    } on XboxLiveException catch (e) {
      pendingCode = null;
      if (!_cancelSignIn) errorMessage = e.message;
      notifyListeners();
      return e.message;
    } catch (_) {
      pendingCode = null;
      errorMessage = 'Microsoft-Anmeldung fehlgeschlagen.';
      notifyListeners();
      return errorMessage;
    }
  }

  void cancelSignIn() {
    _cancelSignIn = true;
    pendingCode = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _store.clear();
    gamertag = null;
    errorMessage = null;
    games = games.where((g) => g.isInstalled).toList();
    notifyListeners();
  }
}
