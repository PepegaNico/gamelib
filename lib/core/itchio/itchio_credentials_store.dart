import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ItchioCredentialsStore {
  ItchioCredentialsStore._();
  static final instance = ItchioCredentialsStore._();

  final _storage = const FlutterSecureStorage();

  static const _apiKeyKey = 'itchio_api_key';

  Future<String?> getApiKey() => _storage.read(key: _apiKeyKey);
  Future<void> setApiKey(String value) =>
      _storage.write(key: _apiKeyKey, value: value);
  Future<void> clearApiKey() => _storage.delete(key: _apiKeyKey);
}
