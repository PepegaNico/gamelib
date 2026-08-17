import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/epic/epic_game.dart';
import '../../core/sync/firebase_auth_service.dart';
import '../../core/sync/firestore_sync_service.dart';
import '../../core/sync/qr_credentials_payload.dart';
import '../../core/sync/sync_credentials_store.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../auth/auth_state.dart';
import '../epic/epic_state.dart';
import '../itchio/itchio_state.dart';
import '../wishlist/wishlist_state.dart';

enum SyncStatus { unknown, loggedOut, loggedIn }

/// Cloud-Sync via a Firebase account: lets the same connected Steam/itch.io/
/// IsThereAnyDeal credentials show up on every device the user logs into,
/// instead of re-entering them on each one — the same data the QR-code
/// transfer moves between two devices in person, just kept converged
/// automatically through the cloud.
class SyncState extends ChangeNotifier {
  SyncState({
    FirebaseAuthService? authService,
    FirestoreSyncService? syncService,
    SyncCredentialsStore? store,
  }) : _authService = authService ?? FirebaseAuthService(),
       _syncService = syncService ?? FirestoreSyncService(),
       _store = store ?? SyncCredentialsStore.instance;

  final FirebaseAuthService _authService;
  final FirestoreSyncService _syncService;
  final SyncCredentialsStore _store;

  SyncStatus status = SyncStatus.unknown;
  String? email;
  String? errorMessage;
  bool isBusy = false;

  String? _uid;
  String? _idToken;
  String? _refreshToken;
  DateTime? _idTokenExpiresAt;

  /// Epic games last pulled from another device's sync — Epic has no
  /// portable credential, so this is a one-way, read-only snapshot rather
  /// than something this device can itself own or re-upload. Populated by
  /// [sync]; combined with any locally-scanned Epic games by whoever calls
  /// this (see LibraryScreen._refresh).
  List<EpicGame> syncedEpicGames = [];

  Future<void> restore() async {
    final saved = await _store.read();
    if (saved == null) {
      status = SyncStatus.loggedOut;
      notifyListeners();
      return;
    }
    _uid = saved.uid;
    email = saved.email;
    _refreshToken = saved.refreshToken;
    status = SyncStatus.loggedIn;
    notifyListeners();
  }

  Future<String?> register(String email, String password) =>
      _authenticate(() => _authService.signUp(email, password), email);

  Future<String?> login(String email, String password) =>
      _authenticate(() => _authService.signIn(email, password), email);

  Future<String?> _authenticate(
    Future<FirebaseAuthResult> Function() action,
    String email,
  ) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await action();
      _uid = result.uid;
      _idToken = result.idToken;
      _refreshToken = result.refreshToken;
      _idTokenExpiresAt = result.expiresAt;
      this.email = email;
      await _store.save(
        uid: result.uid,
        email: email,
        refreshToken: result.refreshToken,
      );
      status = SyncStatus.loggedIn;
      return null;
    } catch (e) {
      errorMessage = e.toString();
      return errorMessage;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _store.clear();
    _uid = null;
    _idToken = null;
    _refreshToken = null;
    _idTokenExpiresAt = null;
    email = null;
    status = SyncStatus.loggedOut;
    notifyListeners();
  }

  Future<String> _validIdToken() async {
    if (_idToken != null &&
        _idTokenExpiresAt != null &&
        DateTime.now().isBefore(
          _idTokenExpiresAt!.subtract(const Duration(minutes: 1)),
        )) {
      return _idToken!;
    }
    final result = await _authService.refresh(
      refreshToken: _refreshToken!,
      fallbackUid: _uid!,
    );
    _idToken = result.idToken;
    _idTokenExpiresAt = result.expiresAt;
    _refreshToken = result.refreshToken;
    await _store.save(uid: _uid!, email: email!, refreshToken: _refreshToken!);
    return _idToken!;
  }

  /// Pulls the cloud state and merges it into the given local states first
  /// (so accounts added on another device show up here), then pushes the
  /// resulting, now-merged local state back up — running this on either
  /// device converges both to the union of connected accounts.
  Future<String?> sync({
    required AuthState auth,
    required ItchioState itchio,
    required WishlistState wishlist,
    required EpicState epic,
  }) async {
    if (status != SyncStatus.loggedIn) return 'Nicht angemeldet.';

    isBusy = true;
    errorMessage = null;
    notifyListeners();

    try {
      final token = await _validIdToken();

      final remoteJson = await _syncService.download(idToken: token, uid: _uid!);
      if (remoteJson != null) {
        final remote = QrCredentialsPayload.decode(remoteJson);
        for (final account in remote.steamAccounts) {
          await auth.importAccount(
            steamId: account.steamId,
            apiKey: account.apiKey,
          );
        }
        for (final key in remote.itchioApiKeys) {
          await itchio.addAccount(key);
        }
        if (remote.itadApiKey != null && !wishlist.hasOwnKey) {
          await wishlist.connect(remote.itadApiKey!);
        }
      }

      final local = QrCredentialsPayload(
        steamAccounts: [
          for (final a in auth.accounts) (steamId: a.steamId, apiKey: a.apiKey),
        ],
        itchioApiKeys: [for (final a in itchio.accounts) a.apiKey],
        itadApiKey: wishlist.apiKey,
      );
      await _syncService.upload(
        idToken: token,
        uid: _uid!,
        payloadJson: local.encode(),
      );

      // Epic has no portable credential — only a device that actually
      // scanned a local Epic library (Windows) can contribute one, so a
      // device with nothing local never overwrites what's already there.
      if (epic.games.isNotEmpty) {
        await _syncService.uploadEpicLibrary(
          idToken: token,
          uid: _uid!,
          payloadJson: jsonEncode(
            [for (final g in epic.games) g.toSyncJson()],
          ),
        );
      } else {
        final epicJson = await _syncService.downloadEpicLibrary(
          idToken: token,
          uid: _uid!,
        );
        if (epicJson != null) {
          syncedEpicGames = (jsonDecode(epicJson) as List)
              .cast<Map<String, dynamic>>()
              .map(EpicGame.fromSyncJson)
              .toList();
        }
      }

      // Wishlist can be edited (added/removed/re-targeted) on either
      // device, unlike accounts — a plain union-merge would mean a deleted
      // entry always comes back from whichever side didn't delete it. Use
      // last-write-wins by timestamp instead: whichever copy changed more
      // recently fully replaces the other.
      final remoteWishlistJson = await _syncService.downloadWishlist(
        idToken: token,
        uid: _uid!,
      );
      if (remoteWishlistJson != null) {
        final decoded = jsonDecode(remoteWishlistJson) as Map<String, dynamic>;
        final remoteUpdatedAt = DateTime.parse(decoded['updatedAt'] as String);
        if (remoteUpdatedAt.isAfter(wishlist.entriesUpdatedAt)) {
          final remoteEntries = (decoded['entries'] as List)
              .cast<Map<String, dynamic>>()
              .map(WishlistEntry.fromJson)
              .toList();
          await wishlist.applyRemote(remoteEntries, remoteUpdatedAt);
        }
      }
      if (wishlist.entries.isNotEmpty ||
          wishlist.entriesUpdatedAt.millisecondsSinceEpoch > 0) {
        await _syncService.uploadWishlist(
          idToken: token,
          uid: _uid!,
          payloadJson: jsonEncode({
            'updatedAt': wishlist.entriesUpdatedAt.toIso8601String(),
            'entries': [for (final e in wishlist.entries) e.toJson()],
          }),
        );
      }
      return null;
    } catch (e) {
      errorMessage = 'Sync fehlgeschlagen: $e';
      return errorMessage;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
