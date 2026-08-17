import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../itad/itad_api_service.dart';
import '../itad/itad_credentials_store.dart';
import '../wishlist/wishlist_store.dart';
import 'local_notification_service.dart';

/// Checks the wishlist's target prices and shows a local notification for
/// each newly-triggered alert. Deliberately self-contained (no
/// BuildContext/Provider) since iOS may invoke this from a background
/// isolate via BackgroundFetch, well outside the normal widget tree.
class BackgroundPriceCheck {
  static const _notifiedIdsKey = 'notified_wishlist_alert_ids';
  static const _storage = FlutterSecureStorage();

  static Future<void> run() async {
    final apiKey = await ItadCredentialsStore.instance.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    final wishlist = await WishlistStore().load();
    final targeted = wishlist.entries
        .where((e) => e.targetPriceAmount != null)
        .toList();
    if (targeted.isEmpty) return;

    final prices = await ItadApiService().getPrices(
      apiKey,
      targeted.map((e) => e.itadGameId).toList(),
    );

    final alreadyNotified = await _loadNotifiedIds();
    final stillBelowTarget = <String>{};

    for (final entry in targeted) {
      final best = prices[entry.itadGameId]?.bestDeal;
      if (best == null || best.price.amount > entry.targetPriceAmount!) {
        continue;
      }

      stillBelowTarget.add(entry.itadGameId);
      if (alreadyNotified.contains(entry.itadGameId)) continue;

      await LocalNotificationService.instance.showPriceAlert(
        id: entry.itadGameId.hashCode,
        title: 'Preisalarm: ${entry.title}',
        body: 'Jetzt für ${best.price.formatted} bei ${best.shopName}.',
      );
    }

    // Entries whose price rose back above target may alert again on a
    // future drop — only entries still below target stay "already notified".
    await _saveNotifiedIds(stillBelowTarget);
  }

  static Future<Set<String>> _loadNotifiedIds() async {
    final raw = await _storage.read(key: _notifiedIdsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  static Future<void> _saveNotifiedIds(Set<String> ids) =>
      _storage.write(key: _notifiedIdsKey, value: jsonEncode(ids.toList()));
}
