import 'dart:convert';

import 'package:http/http.dart' as http;

/// Steam's official Web API wishlist endpoint. The older approach of
/// scraping `store.steampowered.com/wishlist/profiles/.../wishlistdata/`
/// has become unreliable (Steam has tightened access to that page over
/// time) — IWishlistService is the current, documented replacement and
/// needs no more than the public SteamID64.
class SteamWishlistApiService {
  static const _base =
      'https://api.steampowered.com/IWishlistService/GetWishlist/v1/';

  Future<List<int>> getWishlistAppIds({
    required String steamId,
    String? apiKey,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'steamid': steamId,
        if (apiKey != null && apiKey.isNotEmpty) 'key': apiKey,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['response'] as Map<String, dynamic>?)?['items'] as List?;
    if (items == null) return [];

    return items
        .cast<Map<String, dynamic>>()
        .map((item) => item['appid'] as int?)
        .whereType<int>()
        .toList();
  }
}
