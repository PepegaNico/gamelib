import 'dart:convert';

import 'package:http/http.dart' as http;

import 'firebase_config.dart';

/// Reads/writes JSON blobs to `users/{uid}` in Firestore, via Firestore's
/// plain REST API rather than the native `cloud_firestore` plugin — see
/// FirebaseAuthService for why (no reliable Windows support).
///
/// Two independent string fields live on the same document:
/// - `data`: the credentials payload (same format QR-code export uses).
/// - `epicLibrary`: a read-only snapshot of Epic games, since Epic has no
///   portable credential to sync — only Windows (Legendary/local manifest)
///   can ever produce this list, so it's pushed one-way from there.
/// Each field is patched independently (Firestore's updateMask), so a
/// device with nothing to contribute for one field never wipes it.
class FirestoreSyncService {
  static const _dataField = 'data';
  static const _epicLibraryField = 'epicLibrary';

  static String _docUrl(String uid) =>
      'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}'
      '/databases/(default)/documents/users/$uid';

  Future<void> upload({
    required String idToken,
    required String uid,
    required String payloadJson,
  }) => _uploadField(idToken: idToken, uid: uid, field: _dataField, value: payloadJson);

  /// Returns null if no document exists yet (first sync on a fresh account).
  Future<String?> download({required String idToken, required String uid}) =>
      _downloadField(idToken: idToken, uid: uid, field: _dataField);

  Future<void> uploadEpicLibrary({
    required String idToken,
    required String uid,
    required String payloadJson,
  }) => _uploadField(
    idToken: idToken,
    uid: uid,
    field: _epicLibraryField,
    value: payloadJson,
  );

  Future<String?> downloadEpicLibrary({
    required String idToken,
    required String uid,
  }) => _downloadField(idToken: idToken, uid: uid, field: _epicLibraryField);

  Future<void> _uploadField({
    required String idToken,
    required String uid,
    required String field,
    required String value,
  }) async {
    final url = Uri.parse(
      '${_docUrl(uid)}?updateMask.fieldPaths=$field&updateMask.fieldPaths=updatedAt',
    );
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': {
          field: {'stringValue': value},
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

  Future<String?> _downloadField({
    required String idToken,
    required String uid,
    required String field,
  }) async {
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
    return fields?[field]?['stringValue'] as String?;
  }
}
