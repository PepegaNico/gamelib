import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'itchio_account.dart';

class ItchioCredentialsStore {
  ItchioCredentialsStore._();
  static final instance = ItchioCredentialsStore._();

  final _storage = const FlutterSecureStorage();

  static const _accountsKey = 'itchio_accounts_v1';

  // Legacy single-account key, kept only to migrate existing installs.
  static const _legacyApiKeyKey = 'itchio_api_key';

  Future<List<ItchioAccount>> getAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      return list
          .cast<Map<String, dynamic>>()
          .map(ItchioAccount.fromJson)
          .toList();
    }
    return _migrateLegacyAccount();
  }

  Future<void> saveAccounts(List<ItchioAccount> accounts) => _storage.write(
    key: _accountsKey,
    value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
  );

  /// The old single-key storage had no username cached — the caller re-fetches
  /// it once it has restored this account.
  Future<List<ItchioAccount>> _migrateLegacyAccount() async {
    final legacyApiKey = await _storage.read(key: _legacyApiKeyKey);
    if (legacyApiKey == null || legacyApiKey.isEmpty) return [];

    final account = ItchioAccount(apiKey: legacyApiKey, username: '');
    await saveAccounts([account]);
    await _storage.delete(key: _legacyApiKeyKey);
    return [account];
  }
}
