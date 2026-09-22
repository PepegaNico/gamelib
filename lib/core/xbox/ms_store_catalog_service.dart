import 'dart:convert';

import 'package:http/http.dart' as http;

import 'xbox_game.dart';

/// Microsoft's public store catalog (the one behind xbox.com and the
/// Store app) — looked up by package family name, no API key needed.
/// Fills in the real title, box art and description for locally found
/// Xbox/Microsoft Store games.
class MsStoreCatalogService {
  static const _market = 'CH';
  static const _language = 'de-ch';

  Future<void> enrich(XboxGame game) async {
    final uri = Uri.https(
      'displaycatalog.mp.microsoft.com',
      '/v7.0/products/lookup',
      {
        'alternateId': 'PackageFamilyName',
        'value': game.packageFamilyName,
        'market': _market,
        'languages': '$_language,en-us,neutral',
        'fieldsTemplate': 'details',
      },
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final products =
          (jsonDecode(response.body) as Map<String, dynamic>)['Products']
              as List?;
      if (products == null || products.isEmpty) return;
      final product = products.first as Map<String, dynamic>;
      final props =
          ((product['LocalizedProperties'] as List?) ?? []).firstOrNull
              as Map<String, dynamic>?;
      if (props == null) return;

      final images = ((props['Images'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
      String? image(String purpose) {
        final match = images
            .where((i) => i['ImagePurpose'] == purpose)
            .firstOrNull;
        final url = match?['Uri'] as String?;
        if (url == null) return null;
        return url.startsWith('//') ? 'https:$url' : url;
      }

      game.productId = product['ProductId'] as String?;
      final title = props['ProductTitle'] as String?;
      if (title != null && title.isNotEmpty) game.name = title;
      game.posterUrl = image('Poster') ?? image('BoxArt');
      game.heroUrl = image('SuperHeroArt') ?? image('TitledHeroArt');
      game.description = props['ShortDescription'] as String?;
      if (game.description == null || game.description!.isEmpty) {
        game.description = props['ProductDescription'] as String?;
      }
      game.developer =
          (props['DeveloperName'] as String?) ??
          (props['PublisherName'] as String?);
    } catch (_) {
      // Keep the locally-known name; the card falls back to a placeholder.
    }
  }
}
