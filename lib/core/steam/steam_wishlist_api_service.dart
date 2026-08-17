import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches a Steam profile's wishlist app IDs. Tries the official Web API
/// first, then falls back to the older storefront JSON endpoint — Steam's
/// exact behavior here has shifted over time and isn't fully documented, so
/// this hedges between the two rather than betting on one. Either way this
/// only works for a *public* profile/wishlist (same privacy requirement as
/// the rest of the Steam data this app already reads).
class SteamWishlistApiService {
  static const _officialBase =
      'https://api.steampowered.com/IWishlistService/GetWishlist/v1/';
  static const _maxStorefrontPages = 20; // 100 games/page — safety cap

  Future<({List<int> appIds, String? error})> getWishlistAppIds({
    required String steamId,
    String? apiKey,
  }) async {
    final official = await _tryOfficial(steamId, apiKey);
    if (official.appIds.isNotEmpty) return official;

    final storefront = await _tryStorefront(steamId);
    if (storefront.appIds.isNotEmpty) return storefront;

    // Both came back empty — surface whichever has a more specific error.
    return official.error != null ? official : storefront;
  }

  Future<({List<int> appIds, String? error})> _tryOfficial(
    String steamId,
    String? apiKey,
  ) async {
    try {
      final uri = Uri.parse(_officialBase).replace(
        queryParameters: {
          'steamid': steamId,
          if (apiKey != null && apiKey.isNotEmpty) 'key': apiKey,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return (
          appIds: <int>[],
          error: 'Steam-Wishlist-API: HTTP ${response.statusCode}',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['response'] as Map<String, dynamic>?)?['items'] as List?;
      if (items == null) {
        return (
          appIds: <int>[],
          error: 'Steam-Wishlist-API: keine Daten in der Antwort',
        );
      }

      final ids = items
          .cast<Map<String, dynamic>>()
          .map((item) => item['appid'] as int?)
          .whereType<int>()
          .toList();
      return (appIds: ids, error: null);
    } catch (e) {
      return (appIds: <int>[], error: 'Steam-Wishlist-API: $e');
    }
  }

  Future<({List<int> appIds, String? error})> _tryStorefront(
    String steamId,
  ) async {
    try {
      final appIds = <int>[];
      for (var page = 0; page < _maxStorefrontPages; page++) {
        final uri = Uri.parse(
          'https://store.steampowered.com/wishlist/profiles/$steamId/wishlistdata/',
        ).replace(queryParameters: {'p': '$page'});

        final response = await http.get(uri);
        if (response.statusCode != 200) {
          if (page == 0) {
            return (
              appIds: <int>[],
              error:
                  'Steam-Wishlist-Seite: HTTP ${response.statusCode} '
                  '(Profil/Wishlist evtl. nicht öffentlich?)',
            );
          }
          break;
        }

        final body = response.body.trim();
        if (body.isEmpty || body == '[]') break;

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic> || decoded.isEmpty) break;

        for (final key in decoded.keys) {
          final id = int.tryParse(key);
          if (id != null) appIds.add(id);
        }
        if (decoded.length < 100) break;
      }

      return (
        appIds: appIds,
        error: appIds.isEmpty
            ? 'Steam-Wishlist-Seite: keine Einträge gefunden (Profil/Wishlist '
                  'evtl. nicht öffentlich, oder Wishlist ist leer)'
            : null,
      );
    } catch (e) {
      return (appIds: <int>[], error: 'Steam-Wishlist-Seite: $e');
    }
  }
}
