import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the long-lived Firebase refresh token locally so the user stays
/// logged in to Cloud-Sync across app restarts without re-entering a
/// password. The short-lived ID token is never persisted — it's cheap to
/// mint a new one from the refresh token on demand.
class SyncCredentialsStore {
  SyncCredentialsStore._();
  static final instance = SyncCredentialsStore._();

  final _storage = const FlutterSecureStorage();

  static const _uidKey = 'sync_firebase_uid';
  static const _emailKey = 'sync_firebase_email';
  static const _refreshTokenKey = 'sync_firebase_refresh_token';

  Future<({String uid, String email, String refreshToken})?> read() async {
    final uid = await _storage.read(key: _uidKey);
    final email = await _storage.read(key: _emailKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (uid == null || email == null || refreshToken == null) return null;
    return (uid: uid, email: email, refreshToken: refreshToken);
  }

  Future<void> save({
    required String uid,
    required String email,
    required String refreshToken,
  }) async {
    await _storage.write(key: _uidKey, value: uid);
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _uidKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
