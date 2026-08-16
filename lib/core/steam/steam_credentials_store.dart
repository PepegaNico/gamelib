import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's own Steam Web API key and their Steam ID locally.
/// Nothing is ever sent anywhere except directly to Steam's servers.
class SteamCredentialsStore {
  SteamCredentialsStore._();
  static final instance = SteamCredentialsStore._();

  final _storage = const FlutterSecureStorage();

  static const _apiKeyKey = 'steam_api_key';
  static const _steamIdKey = 'steam_id64';
  static const _personaNameKey = 'steam_persona_name';
  static const _avatarUrlKey = 'steam_avatar_url';
  static const _lastNewsCheckKey = 'last_news_check';

  Future<String?> getApiKey() => _storage.read(key: _apiKeyKey);
  Future<void> setApiKey(String value) =>
      _storage.write(key: _apiKeyKey, value: value);
  Future<void> clearApiKey() => _storage.delete(key: _apiKeyKey);

  Future<String?> getSteamId() => _storage.read(key: _steamIdKey);
  Future<void> setSteamId(String value) =>
      _storage.write(key: _steamIdKey, value: value);

  Future<String?> getPersonaName() => _storage.read(key: _personaNameKey);
  Future<void> setPersonaName(String value) =>
      _storage.write(key: _personaNameKey, value: value);

  Future<String?> getAvatarUrl() => _storage.read(key: _avatarUrlKey);
  Future<void> setAvatarUrl(String value) =>
      _storage.write(key: _avatarUrlKey, value: value);

  Future<DateTime?> getLastNewsCheck() async {
    final raw = await _storage.read(key: _lastNewsCheckKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastNewsCheck(DateTime value) =>
      _storage.write(key: _lastNewsCheckKey, value: value.toIso8601String());

  Future<void> clearLogin() async {
    await _storage.delete(key: _steamIdKey);
    await _storage.delete(key: _personaNameKey);
    await _storage.delete(key: _avatarUrlKey);
  }
}
