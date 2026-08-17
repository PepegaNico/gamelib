import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_config.dart';

class FirebaseAuthException implements Exception {
  final String message;
  FirebaseAuthException(this.message);
  @override
  String toString() => message;
}

class FirebaseAuthResult {
  final String uid;
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;

  FirebaseAuthResult({
    required this.uid,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
  });
}

/// Talks to Firebase Authentication over its plain REST API (Identity
/// Toolkit) instead of the native `firebase_auth` plugin — the plugin has no
/// reliable Windows support, while plain HTTPS calls work identically on
/// every platform this app targets.
class FirebaseAuthService {
  static const _accountsBase =
      'https://identitytoolkit.googleapis.com/v1/accounts';
  static const _tokenBase = 'https://securetoken.googleapis.com/v1/token';

  Future<FirebaseAuthResult> signUp(String email, String password) =>
      _accountsRequest('$_accountsBase:signUp', email, password);

  Future<FirebaseAuthResult> signIn(String email, String password) =>
      _accountsRequest('$_accountsBase:signInWithPassword', email, password);

  Future<FirebaseAuthResult> _accountsRequest(
    String url,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$url?key=${FirebaseConfig.webApiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw FirebaseAuthException(_friendlyError(body));
    }
    return FirebaseAuthResult(
      uid: body['localId'] as String,
      idToken: body['idToken'] as String,
      refreshToken: body['refreshToken'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: int.parse(body['expiresIn'] as String)),
      ),
    );
  }

  Future<FirebaseAuthResult> refresh({
    required String refreshToken,
    required String fallbackUid,
  }) async {
    final response = await http.post(
      Uri.parse('$_tokenBase?key=${FirebaseConfig.webApiKey}'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw FirebaseAuthException(_friendlyError(body));
    }
    return FirebaseAuthResult(
      uid: (body['user_id'] as String?) ?? fallbackUid,
      idToken: body['id_token'] as String,
      refreshToken: body['refresh_token'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: int.parse(body['expires_in'] as String)),
      ),
    );
  }

  String _friendlyError(Map<String, dynamic> body) {
    final code = (body['error']?['message'] as String?) ?? '';
    if (code.startsWith('EMAIL_EXISTS')) {
      return 'Diese E-Mail ist bereits registriert.';
    }
    if (code.startsWith('EMAIL_NOT_FOUND') ||
        code.startsWith('INVALID_PASSWORD') ||
        code.startsWith('INVALID_LOGIN_CREDENTIALS')) {
      return 'E-Mail oder Passwort falsch.';
    }
    if (code.startsWith('WEAK_PASSWORD')) {
      return 'Passwort muss mindestens 6 Zeichen haben.';
    }
    if (code.startsWith('INVALID_EMAIL')) {
      return 'Ungültige E-Mail-Adresse.';
    }
    return code.isEmpty ? 'Unbekannter Fehler.' : code;
  }
}
