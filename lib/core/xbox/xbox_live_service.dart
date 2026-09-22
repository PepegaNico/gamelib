import 'dart:convert';

import 'package:http/http.dart' as http;

import 'xbox_game.dart';
import 'xbox_live_config.dart';

class XboxDeviceCode {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final Duration interval;
  final DateTime expiresAt;

  XboxDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresAt,
  });
}

/// Result of a completed Microsoft → Xbox Live sign-in.
class XboxLiveSession {
  final String refreshToken;
  final String xuid;
  final String gamertag;

  /// `XBL3.0 x=<uhs>;<xsts>` — sent as Authorization to Xbox Live APIs.
  final String authorizationHeader;

  XboxLiveSession({
    required this.refreshToken,
    required this.xuid,
    required this.gamertag,
    required this.authorizationHeader,
  });
}

class XboxLiveException implements Exception {
  final String message;
  XboxLiveException(this.message);
  @override
  String toString() => message;
}

/// Official Microsoft identity platform (device code flow, so no redirect
/// handling is needed in a desktop app) followed by the standard Xbox Live
/// token exchange: MSA access token → Xbox user token → XSTS token. Then
/// reads the account's title history — every game played on Xbox consoles,
/// PC and cloud, with achievement progress.
class XboxLiveService {
  static const _authority =
      'https://login.microsoftonline.com/consumers/oauth2/v2.0';
  static const _scope = 'XboxLive.signin offline_access';

  Future<XboxDeviceCode> startDeviceCode() async {
    final response = await http.post(
      Uri.parse('$_authority/devicecode'),
      body: {'client_id': XboxLiveConfig.clientId, 'scope': _scope},
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw XboxLiveException(
        'Microsoft-Anmeldung konnte nicht gestartet werden '
        '(${json['error_description'] ?? response.statusCode}).',
      );
    }
    return XboxDeviceCode(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      interval: Duration(seconds: (json['interval'] as num?)?.toInt() ?? 5),
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 900),
      ),
    );
  }

  /// Polls until the user has entered the code on microsoft.com, then
  /// completes the Xbox Live exchange. [isCancelled] lets the UI abort.
  Future<XboxLiveSession> completeDeviceCode(
    XboxDeviceCode code, {
    required bool Function() isCancelled,
  }) async {
    var interval = code.interval;
    while (DateTime.now().isBefore(code.expiresAt)) {
      await Future<void>.delayed(interval);
      if (isCancelled()) throw XboxLiveException('Anmeldung abgebrochen.');

      final response = await http.post(
        Uri.parse('$_authority/token'),
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': XboxLiveConfig.clientId,
          'device_code': code.deviceCode,
        },
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return _exchangeForXboxLive(
          accessToken: json['access_token'] as String,
          refreshToken: json['refresh_token'] as String,
        );
      }
      switch (json['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += const Duration(seconds: 5);
          continue;
        case 'authorization_declined':
          throw XboxLiveException('Anmeldung wurde abgelehnt.');
        default:
          throw XboxLiveException(
            'Microsoft-Anmeldung fehlgeschlagen '
            '(${json['error_description'] ?? json['error']}).',
          );
      }
    }
    throw XboxLiveException('Der Code ist abgelaufen. Bitte erneut anmelden.');
  }

  /// Re-derives a fresh session from a stored refresh token.
  Future<XboxLiveSession> refresh(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$_authority/token'),
      body: {
        'grant_type': 'refresh_token',
        'client_id': XboxLiveConfig.clientId,
        'refresh_token': refreshToken,
        'scope': _scope,
      },
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw XboxLiveException(
        'Xbox-Anmeldung abgelaufen. Bitte erneut anmelden.',
      );
    }
    return _exchangeForXboxLive(
      accessToken: json['access_token'] as String,
      refreshToken: (json['refresh_token'] as String?) ?? refreshToken,
    );
  }

  Future<XboxLiveSession> _exchangeForXboxLive({
    required String accessToken,
    required String refreshToken,
  }) async {
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-xbl-contract-version': '1',
    };

    final userResponse = await http.post(
      Uri.parse('https://user.auth.xboxlive.com/user/authenticate'),
      headers: headers,
      body: jsonEncode({
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=$accessToken',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      }),
    );
    if (userResponse.statusCode != 200) {
      throw XboxLiveException(
        'Xbox-Live-Anmeldung fehlgeschlagen (${userResponse.statusCode}).',
      );
    }
    final userToken =
        (jsonDecode(userResponse.body) as Map<String, dynamic>)['Token']
            as String;

    final xstsResponse = await http.post(
      Uri.parse('https://xsts.auth.xboxlive.com/xsts/authorize'),
      headers: headers,
      body: jsonEncode({
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [userToken],
        },
        'RelyingParty': 'http://xboxlive.com',
        'TokenType': 'JWT',
      }),
    );
    final xsts = jsonDecode(xstsResponse.body) as Map<String, dynamic>;
    if (xstsResponse.statusCode != 200) {
      throw XboxLiveException(switch (xsts['XErr']) {
        2148916233 =>
          'Dieses Microsoft-Konto hat noch kein Xbox-Profil. '
              'Melde dich einmal auf xbox.com an.',
        2148916238 =>
          'Kinderkonten müssen von einem Erwachsenen zur Xbox-Familie '
              'hinzugefügt werden.',
        _ => 'Xbox-Live-Anmeldung fehlgeschlagen (${xstsResponse.statusCode}).',
      });
    }
    final claims =
        ((xsts['DisplayClaims'] as Map<String, dynamic>)['xui'] as List).first
            as Map<String, dynamic>;

    return XboxLiveSession(
      refreshToken: refreshToken,
      xuid: claims['xid'] as String,
      gamertag: (claims['gtg'] as String?) ?? 'Xbox',
      authorizationHeader: 'XBL3.0 x=${claims['uhs']};${xsts['Token']}',
    );
  }

  /// Every game this account has played on any Xbox device or PC.
  Future<List<XboxGame>> titleHistory(XboxLiveSession session) async {
    final response = await http.get(
      Uri.parse(
        'https://titlehub.xboxlive.com/users/xuid(${session.xuid})/titles/'
        'titlehistory/decoration/achievement,image,detail',
      ),
      headers: {
        'Authorization': session.authorizationHeader,
        'x-xbl-contract-version': '2',
        'Accept': 'application/json',
        'Accept-Language': 'de-CH',
      },
    );
    if (response.statusCode != 200) {
      throw XboxLiveException(
        'Xbox-Spiele konnten nicht geladen werden (${response.statusCode}).',
      );
    }
    final titles =
        ((jsonDecode(response.body) as Map<String, dynamic>)['titles']
                    as List? ??
                [])
            .cast<Map<String, dynamic>>();

    return [
      for (final title in titles)
        if (title['type'] == 'Game') XboxGame.fromTitleHub(title),
    ];
  }
}
