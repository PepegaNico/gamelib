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

  const QrCredentialsPayload({
    required this.steamAccounts,
    required this.itchioApiKeys,
    required this.itadApiKey,
  });

  bool get isEmpty =>
      steamAccounts.isEmpty && itchioApiKeys.isEmpty && itadApiKey == null;

  String encode() {
    final map = <String, dynamic>{
      'v': 1,
      'steam': [
        for (final a in steamAccounts) {'id': a.steamId, 'key': a.apiKey},
      ],
      'itchio': itchioApiKeys,
      if (itadApiKey != null) 'itad': itadApiKey,
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

    return QrCredentialsPayload(
      steamAccounts: steam,
      itchioApiKeys: itchio,
      itadApiKey: itad,
    );
  }
}
