import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_config.dart';

/// Reads/writes a single JSON blob (the same format produced by
/// [QrCredentialsPayload.encode]) to `users/{uid}` in Firestore, via
/// Firestore's plain REST API rather than the native `cloud_firestore`
/// plugin — see FirebaseAuthService for why (no reliable Windows support).
class FirestoreSyncService {
  static String _docUrl(String uid) =>
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents/users/$uid';

  Future<void> upload({
    required String idToken,
    required String uid,
    required String payloadJson,
  }) async {
    final url = Uri.parse(
      '${_docUrl(uid)}?updateMask.fieldPaths=data&updateMask.fieldPaths=updatedAt',
    );
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': {
          'data': {'stringValue': payloadJson},
          'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        },
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Sync-Upload fehlgeschlagen (Status ${response.statusCode}).',
      );
    }
  }

  /// Returns null if no document exists yet (first sync on a fresh account).
  Future<String?> download({required String idToken, required String uid}) async {
    final response = await http.get(
      Uri.parse(_docUrl(uid)),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Sync-Download fehlgeschlagen (Status ${response.statusCode}).',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final fields = body['fields'] as Map<String, dynamic>?;
    return fields?['data']?['stringValue'] as String?;
  }
}
