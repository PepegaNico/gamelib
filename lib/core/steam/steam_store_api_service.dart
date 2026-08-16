import 'dart:convert';

import 'package:http/http.dart' as http;

import 'steam_app_details.dart';

/// The Steam Storefront API (store.steampowered.com/api/appdetails) is
/// unofficial and undocumented but widely used and key-free. Kept separate
/// from [SteamWebApiService] because it's a different host/contract and can
/// fail per-app (e.g. delisted games) without that being a real error.
class SteamStoreApiService {
  static const _base = 'https://store.steampowered.com/api/appdetails';

  /// Also used to classify store search results (via [SteamAppDetails.type]
  /// and `.genres`) — Steam's search endpoint itself reports every result
  /// as a generic "app" and doesn't include genres, only appdetails does.
  Future<SteamAppDetails?> getAppDetails(int appId) async {
    try {
      final uri = Uri.parse(_base)
          .replace(queryParameters: {'appids': '$appId', 'l': 'german'});

      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entry = body['$appId'] as Map<String, dynamic>?;
      if (entry == null || entry['success'] != true) return null;

      final data = entry['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      return SteamAppDetails.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
