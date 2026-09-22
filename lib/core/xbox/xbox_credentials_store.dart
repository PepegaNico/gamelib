import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the Microsoft refresh token for the Xbox account in the OS
/// credential store — everything else (Xbox Live tokens) is short-lived and
/// re-derived from it.
class XboxCredentialsStore {
  XboxCredentialsStore._();
  static final instance = XboxCredentialsStore._();

  final _storage = const FlutterSecureStorage();
  static const _refreshTokenKey = 'xbox_ms_refresh_token_v1';

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}
