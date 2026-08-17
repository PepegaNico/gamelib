import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'steam_account.dart';

/// Persists the user's connected Steam accounts (each with their own Web-API
/// key and SteamID64) locally. Nothing is ever sent anywhere except directly
/// to Steam's servers.
class SteamCredentialsStore {
  SteamCredentialsStore._();
  static final instance = SteamCredentialsStore._();

  final _storage = const FlutterSecureStorage();

  static const _accountsKey = 'steam_accounts_v1';
  static const _lastNewsCheckKey = 'last_news_check';

  // Legacy single-account keys, kept only to migrate existing installs.
  static const _legacyApiKeyKey = 'steam_api_key';
  static const _legacySteamIdKey = 'steam_id64';
  static const _legacyPersonaNameKey = 'steam_persona_name';
  static const _legacyAvatarUrlKey = 'steam_avatar_url';

  Future<List<SteamAccount>> getAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      return list
          .cast<Map<String, dynamic>>()
          .map(SteamAccount.fromJson)
          .toList();
    }
    return _migrateLegacyAccount();
  }

  Future<void> saveAccounts(List<SteamAccount> accounts) => _storage.write(
    key: _accountsKey,
    value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
  );

  /// Reads the pre-multi-account single-account fields, if any, converts
  /// them into the new list format once, then clears the old keys.
  Future<List<SteamAccount>> _migrateLegacyAccount() async {
    final legacyApiKey = await _storage.read(key: _legacyApiKeyKey);
    final legacySteamId = await _storage.read(key: _legacySteamIdKey);
    if (legacyApiKey == null ||
        legacyApiKey.isEmpty ||
        legacySteamId == null ||
        legacySteamId.isEmpty) {
      return [];
    }

    final account = SteamAccount(
      steamId: legacySteamId,
      apiKey: legacyApiKey,
      personaName:
          await _storage.read(key: _legacyPersonaNameKey) ?? 'Steam-Nutzer',
      avatarUrl: await _storage.read(key: _legacyAvatarUrlKey) ?? '',
    );
    await saveAccounts([account]);
    await _storage.delete(key: _legacyApiKeyKey);
    await _storage.delete(key: _legacySteamIdKey);
    await _storage.delete(key: _legacyPersonaNameKey);
    await _storage.delete(key: _legacyAvatarUrlKey);
    return [account];
  }

  Future<DateTime?> getLastNewsCheck() async {
    final raw = await _storage.read(key: _lastNewsCheckKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastNewsCheck(DateTime value) =>
      _storage.write(key: _lastNewsCheckKey, value: value.toIso8601String());
}
