import 'dart:convert';

import 'package:http/http.dart' as http;

import 'playstation_game.dart';

class PsnSession {
  final String accessToken;
  final String refreshToken;

  PsnSession({required this.accessToken, required this.refreshToken});
}

class PsnException implements Exception {
  final String message;
  PsnException(this.message);
  @override
  String toString() => message;
}

/// PlayStation Network has no public API. This follows the flow the
/// open-source psn-api library (github.com/achievements-app/psn-api)
/// documents: the user copies their NPSSO cookie after signing in on
/// playstation.com, which is exchanged for OAuth tokens of the PlayStation
/// mobile app's public client. Unofficial — Sony can change or block it
/// at any time, so every failure surfaces as a readable message.
class PsnApiService {
  static const _authBase = 'https://ca.account.sony.com/api/authz/v3/oauth';
  static const _clientId = '09515159-7237-4370-9b40-3806e67c0891';
  static const _redirectUri = 'com.scee.psxandroid.scecompcall://redirect';
  static const _scope = 'psn:mobile.v2.core psn:clientapp';

  /// Base64 of `client id:client secret` of that public mobile client,
  /// as published by psn-api.
  static const _basicAuth =
      'Basic MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A=';

  /// Exchanges a freshly copied NPSSO code for a session.
  Future<PsnSession> signInWithNpsso(String npsso) async {
    final authorize =
        http.Request(
            'GET',
            Uri.parse('$_authBase/authorize').replace(
              queryParameters: {
                'access_type': 'offline',
                'client_id': _clientId,
                'redirect_uri': _redirectUri,
                'response_type': 'code',
                'scope': _scope,
              },
            ),
          )
          ..followRedirects = false
          ..headers['Cookie'] = 'npsso=$npsso';

    final client = http.Client();
    try {
      final response = await client.send(authorize);
      final location = response.headers['location'] ?? '';
      final code = Uri.tryParse(location)?.queryParameters['code'];
      if (code == null) {
        throw PsnException(
          'Der NPSSO-Code ist ungültig oder abgelaufen. Melde dich auf '
          'playstation.com erneut an und kopiere einen neuen Code.',
        );
      }
      return await _token({
        'code': code,
        'redirect_uri': _redirectUri,
        'grant_type': 'authorization_code',
        'token_format': 'jwt',
      });
    } finally {
      client.close();
    }
  }

  Future<PsnSession> refresh(String refreshToken) => _token({
    'refresh_token': refreshToken,
    'grant_type': 'refresh_token',
    'token_format': 'jwt',
    'scope': _scope,
  });

  Future<PsnSession> _token(Map<String, String> body) async {
    final response = await http.post(
      Uri.parse('$_authBase/token'),
      headers: {'Authorization': _basicAuth},
      body: body,
    );
    if (response.statusCode != 200) {
      throw PsnException(
        'PlayStation-Anmeldung abgelaufen. Bitte mit einem neuen '
        'NPSSO-Code erneut verbinden.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PsnSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  Future<String?> onlineId(PsnSession session) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://us-prof.np.community.playstation.net/userProfile/v1/'
          'users/me/profile2?fields=onlineId',
        ),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      if (response.statusCode != 200) return null;
      final profile =
          (jsonDecode(response.body) as Map<String, dynamic>)['profile']
              as Map<String, dynamic>?;
      return profile?['onlineId'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Every PS4/PS5 game the account has played, with playtime.
  Future<List<PlaystationGame>> playedGames(PsnSession session) async {
    final games = <PlaystationGame>[];
    int? offset = 0;
    while (offset != null) {
      final response = await http.get(
        Uri.parse(
          'https://m.np.playstation.com/api/gamelist/v2/users/me/titles',
        ).replace(
          queryParameters: {
            'categories': 'ps4_game,ps5_native_game',
            'limit': '200',
            'offset': '$offset',
          },
        ),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Accept-Language': 'de-CH',
        },
      );
      if (response.statusCode != 200) {
        throw PsnException(
          'PlayStation-Spiele konnten nicht geladen werden '
          '(${response.statusCode}).',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      games.addAll(
        ((json['titles'] as List?) ?? []).cast<Map<String, dynamic>>().map(
          PlaystationGame.fromGameList,
        ),
      );
      offset = (json['nextOffset'] as num?)?.toInt();
    }
    return games;
  }
}
