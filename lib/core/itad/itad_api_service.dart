import 'dart:convert';

import 'package:http/http.dart' as http;

import 'itad_models.dart';

class ItadApiException implements Exception {
  final String message;
  ItadApiException(this.message);
  @override
  String toString() => message;
}

/// IsThereAnyDeal API v2 (https://docs.isthereanydeal.com) — key-based
/// auth like Steam/itch.io, no OAuth needed for anything used here. ITAD's
/// own wishlist/webhook system is OAuth2-only, so price-alerting is done
/// entirely client-side instead: we keep our own local wishlist and poll
/// [getPrices] against it (see WishlistState).
class ItadApiService {
  static const _base = 'https://api.isthereanydeal.com';

  Future<ItadGameMatch?> lookupBySteamAppId(String apiKey, int appId) async {
    final uri = Uri.parse('$_base/games/lookup/v1')
        .replace(queryParameters: {'key': apiKey, 'appid': '$appId'});
    return _lookup(uri);
  }

  Future<ItadGameMatch?> lookupByTitle(String apiKey, String title) async {
    final uri = Uri.parse('$_base/games/lookup/v1')
        .replace(queryParameters: {'key': apiKey, 'title': title});
    return _lookup(uri);
  }

  Future<ItadGameMatch?> _lookup(Uri uri) async {
    final response = await http.get(uri);
    if (response.statusCode == 403) {
      throw ItadApiException('Der IsThereAnyDeal-API-Key ist ungültig.');
    }
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['found'] != true) return null;
    return ItadGameMatch.fromJson(body['game'] as Map<String, dynamic>);
  }

  Future<List<ItadGameMatch>> search(
    String apiKey,
    String title, {
    int results = 20,
  }) async {
    if (title.trim().isEmpty) return [];

    final uri = Uri.parse('$_base/games/search/v1').replace(
      queryParameters: {
        'key': apiKey,
        'title': title.trim(),
        'results': '$results',
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as List;
    return body
        .cast<Map<String, dynamic>>()
        .map(ItadGameMatch.fromJson)
        .toList();
  }

  /// Batch price + all-time-low lookup, up to 200 game IDs per call.
  Future<Map<String, ItadPriceInfo>> getPrices(
    String apiKey,
    List<String> gameIds, {
    String country = 'DE',
  }) async {
    if (gameIds.isEmpty) return {};

    final result = <String, ItadPriceInfo>{};
    for (var i = 0; i < gameIds.length; i += 200) {
      final batch = gameIds.sublist(i, (i + 200).clamp(0, gameIds.length));
      final uri = Uri.parse('$_base/games/prices/v3')
          .replace(queryParameters: {'key': apiKey, 'country': country});

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(batch),
      );
      if (response.statusCode != 200) continue;

      final body = jsonDecode(response.body) as List;
      for (final entry in body.cast<Map<String, dynamic>>()) {
        final info = ItadPriceInfo.fromJson(entry);
        result[info.gameId] = info;
      }
    }
    return result;
  }
}
