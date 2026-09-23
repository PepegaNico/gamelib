import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the PlayStation refresh token (valid ~2 months) in the OS
/// credential store. The NPSSO code itself is never stored.
class PsnCredentialsStore {
  PsnCredentialsStore._();
  static final instance = PsnCredentialsStore._();

  final _storage = const FlutterSecureStorage();
  static const _refreshTokenKey = 'psn_refresh_token_v1';

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}
