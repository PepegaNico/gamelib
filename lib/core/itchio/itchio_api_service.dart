import 'dart:convert';

import 'package:http/http.dart' as http;

import 'itchio_game.dart';

class ItchioApiException implements Exception {
  final String message;
  ItchioApiException(this.message);
  @override
  String toString() => message;
}

/// itch.io's server-side API (https://api.itch.io) authenticates with a
/// personal API key as a bearer token — same "user brings their own key"
/// model as the Steam integration, no OAuth/hosting needed.
class ItchioApiService {
  static const _base = 'https://api.itch.io';

  Future<String> getUsername(String apiKey) async {
    final response = await http.get(
      Uri.parse('$_base/profile'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw ItchioApiException('Der itch.io-API-Key ist ungültig.');
    }
    if (response.statusCode != 200) {
      throw ItchioApiException(
        'itch.io hat mit Status ${response.statusCode} geantwortet.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'] as Map<String, dynamic>?;
    return (user?['display_name'] as String?) ??
        (user?['username'] as String?) ??
        'itch.io-Nutzer';
  }

  Future<List<ItchioGame>> getOwnedGames(String apiKey) async {
    final games = <ItchioGame>[];
    var page = 1;

    while (true) {
      final uri = Uri.parse('$_base/profile/owned-keys')
          .replace(queryParameters: {'page': '$page'});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ItchioApiException(
          'Der itch.io-API-Key ist ungültig oder hat nicht die nötige Berechtigung.',
        );
      }
      if (response.statusCode != 200) {
        throw ItchioApiException(
          'itch.io hat mit Status ${response.statusCode} geantwortet.',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final ownedKeys =
          (body['owned_keys'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (ownedKeys.isEmpty) break;

      games.addAll(
        ownedKeys
            .map(ItchioGame.fromDownloadKeyJson)
            .where((g) => g.gameId != 0),
      );

      // The API returns fewer than a full page once we've reached the end.
      final perPage = (body['per_page'] as int?) ?? ownedKeys.length;
      if (ownedKeys.length < perPage) break;
      page++;
    }

    return games;
  }
}
