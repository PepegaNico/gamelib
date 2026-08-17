import 'dart:convert';

import 'package:http/http.dart' as http;

/// Steam's wishlist page ships its data as plain, unauthenticated JSON —
/// there's no official Web API equivalent, but this is the same endpoint
/// Steam's own store website uses internally and it's been stable for
/// years. Only works if the profile's wishlist is set to public (same
/// privacy setting as the rest of the profile this app already reads).
class SteamWishlistApiService {
  static const _maxPages = 20; // 100 games/page — safety cap, not a real limit

  Future<List<int>> getWishlistAppIds(String steamId) async {
    final appIds = <int>[];

    for (var page = 0; page < _maxPages; page++) {
      final uri = Uri.parse(
        'https://store.steampowered.com/wishlist/profiles/$steamId/wishlistdata/',
      ).replace(queryParameters: {'p': '$page'});

      final response = await http.get(uri);
      if (response.statusCode != 200) break;

      final body = response.body.trim();
      if (body.isEmpty || body == '[]') break;

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) break;

      for (final key in decoded.keys) {
        final id = int.tryParse(key);
        if (id != null) appIds.add(id);
      }
      if (decoded.length < 100) break; // last page
    }

    return appIds;
  }
}
