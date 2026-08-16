import 'dart:convert';

import 'package:http/http.dart' as http;

import 'steam_store_listing.dart';

/// Steam's public storefront search and featured-categories endpoints —
/// the same undocumented-but-widely-used, key-free, no-login APIs that
/// power the search box and front page of the Steam store website itself.
class SteamStoreSearchService {
  static const _searchEndpoint =
      'https://store.steampowered.com/api/storesearch/';
  static const _featuredEndpoint =
      'https://store.steampowered.com/api/featuredcategories';

  Future<List<SteamStoreListing>> search(String term, {int count = 30}) async {
    if (term.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(_searchEndpoint).replace(
        queryParameters: {'term': term.trim(), 'l': 'german', 'cc': 'DE'},
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items =
          (body['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      return items
          .where((i) => i['type'] == 'app')
          .map(SteamStoreListing.fromJson)
          .take(count)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Current storewide deals — same data as the Steam store front page's
  /// "Specials" row.
  Future<List<SteamStoreListing>> getDeals({int count = 30}) async {
    final category = await _getFeaturedCategory('specials');
    return category.take(count).toList();
  }

  Future<List<SteamStoreListing>> _getFeaturedCategory(String key) async {
    try {
      final uri = Uri.parse(_featuredEndpoint)
          .replace(queryParameters: {'l': 'german', 'cc': 'DE'});
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body[key] as Map<String, dynamic>?)?['items'] as List?;
      if (items == null) return [];

      return items
          .cast<Map<String, dynamic>>()
          .map(SteamStoreListing.fromFeaturedJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
