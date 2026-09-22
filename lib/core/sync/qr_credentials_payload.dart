import 'dart:convert';

/// A compact, versioned bundle of the credentials needed to sign the same
/// accounts into another device — used for the QR-code device-to-device
/// transfer (see qr_export_screen.dart / qr_import_screen.dart).
///
/// Display names/avatars are deliberately left out to keep the QR code small
/// and simple; the importing device re-fetches them from each provider,
/// which also doubles as a validity check for the transferred key.
class QrCredentialsPayload {
  final List<({String steamId, String apiKey})> steamAccounts;
  final List<String> itchioApiKeys;
  final String? itadApiKey;

  /// A Firebase Cloud-Sync refresh token — lets the scanning device pair
  /// into the same Cloud-Sync account (and from there pull e.g. the Epic
  /// library snapshot) without re-typing an email/password. A refresh
  /// token rather than the password itself, so a leaked/screenshotted QR
  /// only exposes a revocable session, not the account credential. Only
  /// set when the exporting device is actually logged into Cloud-Sync.
  final String? syncRefreshToken;

  const QrCredentialsPayload({
    required this.steamAccounts,
    required this.itchioApiKeys,
    required this.itadApiKey,
    this.syncRefreshToken,
  });

  bool get isEmpty =>
      steamAccounts.isEmpty &&
      itchioApiKeys.isEmpty &&
      itadApiKey == null &&
      syncRefreshToken == null;

  String encode() {
    final map = <String, dynamic>{
      'v': 1,
      'steam': [
        for (final a in steamAccounts) {'id': a.steamId, 'key': a.apiKey},
      ],
      'itchio': itchioApiKeys,
      if (itadApiKey != null) 'itad': itadApiKey,
      if (syncRefreshToken != null) 'syncToken': syncRefreshToken,
    };
    return jsonEncode(map);
  }

  static QrCredentialsPayload decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['v'] != 1) {
      throw const FormatException(
        'Das ist kein gültiger GameLib-Sync-QR-Code.',
      );
    }

    final steam = <({String steamId, String apiKey})>[
      for (final entry in (decoded['steam'] as List? ?? []))
        (
          steamId: (entry as Map<String, dynamic>)['id'] as String,
          apiKey: entry['key'] as String,
        ),
    ];
    final itchio = (decoded['itchio'] as List? ?? []).cast<String>();
    final itad = decoded['itad'] as String?;
    final syncToken = decoded['syncToken'] as String?;

    return QrCredentialsPayload(
      steamAccounts: steam,
      itchioApiKeys: itchio,
      itadApiKey: itad,
      syncRefreshToken: syncToken,
    );
  }
}
