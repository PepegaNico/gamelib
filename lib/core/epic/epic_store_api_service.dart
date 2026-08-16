import 'dart:convert';
import 'dart:io';

import 'epic_store_listing.dart';

/// The public, unauthenticated GraphQL endpoint that powers
/// store.epicgames.com's own search. Read-only catalog data, no login, no
/// personal data involved — same risk profile as Steam's public store API.
///
/// The endpoint sits behind Cloudflare bot detection that fingerprints at
/// the TLS layer (JA3/JA4), not just HTTP headers — verified that identical
/// requests get a 403 challenge page from Dart's own HTTP client (BoringSSL
/// via the Dart VM) but a clean 200 from curl.exe (Windows' native Schannel
/// TLS stack) even with byte-identical headers. Rather than fight that at
/// the socket level, requests are shelled out to the curl.exe bundled with
/// Windows since 10 (1803), which Cloudflare doesn't flag.
class EpicStoreApiService {
  static const _endpoint = 'https://store.epicgames.com/graphql';

  static const _headers = {
    'Content-Type: application/json',
    'Accept: */*',
    'Accept-Language: en-US,en;q=0.9',
    'Origin: https://store.epicgames.com',
    'Referer: https://store.epicgames.com/en-US/browse',
    'sec-ch-ua: "Chromium";v="120", "Not?A_Brand";v="24"',
    'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  static const _searchQuery = r'''
query searchStoreQuery($allowCountries: String, $category: String, $count: Int, $country: String!, $keywords: String, $locale: String, $namespace: String, $itemNs: String, $sortBy: String, $sortDir: String, $start: Int, $tag: String, $releaseDate: String, $onSale: Boolean, $withPrice: Boolean = false) {
  Catalog {
    searchStore(allowCountries: $allowCountries, category: $category, count: $count, country: $country, keywords: $keywords, locale: $locale, namespace: $namespace, itemNs: $itemNs, sortBy: $sortBy, sortDir: $sortDir, releaseDate: $releaseDate, start: $start, tag: $tag, onSale: $onSale) {
      elements {
        title
        id
        namespace
        description
        effectiveDate
        keyImages {
          type
          url
        }
        seller {
          name
        }
        categories {
          path
        }
        productSlug
        urlSlug
        url
        price(country: $country) @include(if: $withPrice) {
          totalPrice {
            discountPrice
            originalPrice
            currencyCode
          }
        }
      }
      paging {
        count
        total
      }
    }
  }
}
''';

  /// Posts a GraphQL request via curl.exe and returns the decoded JSON
  /// body, or null if curl is missing, the request fails, or the response
  /// isn't valid JSON (e.g. a Cloudflare challenge page slipping through).
  ///
  /// Windows-only: this shells out to curl.exe (see the class doc for why),
  /// and mobile platforms can't spawn subprocesses at all — Epic store
  /// search/deals just aren't available there for now.
  Future<Map<String, dynamic>?> _post(Map<String, dynamic> payload) async {
    if (!Platform.isWindows) return null;
    try {
      final args = <String>['-s', _endpoint];
      for (final header in _headers) {
        args.addAll(['-H', header]);
      }
      args.addAll(['-d', jsonEncode(payload)]);

      // curl always writes UTF-8 regardless of the system codepage — without
      // this, stdout gets decoded with the Windows console's default
      // encoding and non-ASCII characters (™, ®, umlauts, …) turn to mojibake.
      final result = await Process.run('curl.exe', args, stdoutEncoding: utf8);
      if (result.exitCode != 0) return null;

      final stdout = (result.stdout as String).trim();
      if (!stdout.startsWith('{')) return null;

      return jsonDecode(stdout) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<EpicStoreListing>> search(
    String keywords, {
    int count = 30,
  }) async {
    if (keywords.trim().isEmpty) return [];

    return _runSearch({
      'keywords': keywords.trim(),
      'category': 'games/edition/base|bundles/games|editors',
      'count': count,
      'country': 'US',
      'locale': 'de',
      'sortBy': 'relevancy',
      'sortDir': 'DESC',
      'start': 0,
      'withPrice': true,
    });
  }

  /// Current storewide deals — no keywords needed, just `onSale: true`.
  /// Mirrors the Epic Store front page's discount browsing.
  Future<List<EpicStoreListing>> getDeals({int count = 30}) async {
    return _runSearch({
      'category': 'games/edition/base',
      'count': count,
      'country': 'US',
      'locale': 'de',
      'sortBy': 'relevancy',
      'sortDir': 'DESC',
      'start': 0,
      'onSale': true,
      'withPrice': true,
    });
  }

  Future<List<EpicStoreListing>> _runSearch(
    Map<String, dynamic> variables,
  ) async {
    final body = await _post({'query': _searchQuery, 'variables': variables});
    if (body == null) return [];

    final elements =
        body['data']?['Catalog']?['searchStore']?['elements'] as List?;
    if (elements == null) return [];

    return elements
        .cast<Map<String, dynamic>>()
        .map(EpicStoreListing.fromJson)
        .where((listing) => listing.id.isNotEmpty)
        .toList();
  }

  /// Best-effort lookup of a single owned game by exact title match.
  Future<EpicStoreListing?> findByTitle(String title) async {
    final results = await search(title, count: 5);
    if (results.isEmpty) return null;

    final exactMatch = results.where(
      (r) => r.title.toLowerCase() == title.toLowerCase(),
    );
    return exactMatch.isNotEmpty ? exactMatch.first : results.first;
  }
}
