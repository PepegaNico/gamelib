import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Signs the user in via Steam's OpenID 2.0 login.
///
/// Steam has no OAuth/scopes — OpenID only proves "this browser belongs to
/// SteamID X". We run a local loopback HTTP server so Steam can redirect
/// back into the app after login, then validate the response directly
/// against Steam's servers (no backend of ours involved).
class SteamOpenIdService {
  static final _claimedIdSteamId = RegExp(
    r'steamcommunity\.com/openid/id/(\d+)$',
  );

  /// Runs the full login flow and returns the authenticated SteamID64,
  /// or null if the user cancelled/closed the browser tab without finishing.
  Future<String?> signIn({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final realm = 'http://localhost:$port';
    final returnTo = '$realm/callback';

    try {
      final loginUrl = Uri.https('steamcommunity.com', '/openid/login', {
        'openid.ns': 'http://specs.openid.net/auth/2.0',
        'openid.mode': 'checkid_setup',
        'openid.return_to': returnTo,
        'openid.realm': realm,
        'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.claimed_id':
            'http://specs.openid.net/auth/2.0/identifier_select',
      });

      final launched = await launchUrl(
        loginUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Der Browser konnte nicht geöffnet werden.');
      }

      final request = await server.first.timeout(timeout);
      final steamId = await _handleCallback(request);
      return steamId;
    } finally {
      await server.close(force: true);
    }
  }

  Future<String?> _handleCallback(HttpRequest request) async {
    final params = request.uri.queryParameters;
    String responseHtml;
    String? steamId;

    try {
      if (params['openid.mode'] == 'id_res') {
        final isValid = await _verifyWithSteam(params);
        if (isValid) {
          final claimedId = params['openid.claimed_id'] ?? '';
          steamId = _claimedIdSteamId.firstMatch(claimedId)?.group(1);
        }
      }
      responseHtml = steamId != null
          ? _resultPage(success: true)
          : _resultPage(success: false);
    } catch (_) {
      responseHtml = _resultPage(success: false);
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(responseHtml);
    await request.response.close();

    return steamId;
  }

  /// Steam OpenID has no shared secret — validation means echoing the
  /// signed params back to Steam with mode=check_authentication and
  /// trusting its "is_valid:true" response.
  Future<bool> _verifyWithSteam(Map<String, String> params) async {
    final verifyParams = Map<String, String>.from(params)
      ..['openid.mode'] = 'check_authentication';

    final response = await http.post(
      Uri.https('steamcommunity.com', '/openid/login'),
      body: verifyParams,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    return response.statusCode == 200 &&
        response.body.contains('is_valid:true');
  }

  String _resultPage({required bool success}) {
    final title = success
        ? 'Anmeldung erfolgreich'
        : 'Anmeldung fehlgeschlagen';
    final message = success
        ? 'Du kannst dieses Fenster jetzt schließen und zur App zurückkehren.'
        : 'Die Anmeldung war nicht erfolgreich. Du kannst dieses Fenster schließen und es erneut versuchen.';
    return '''
<!DOCTYPE html>
<html lang="de">
<head><meta charset="utf-8"><title>$title</title></head>
<body style="font-family: sans-serif; text-align: center; padding-top: 4rem;">
  <h2>$title</h2>
  <p>$message</p>
</body>
</html>
''';
  }
}
