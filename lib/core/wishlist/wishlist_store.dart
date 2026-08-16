import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'wishlist_entry.dart';

/// Local-only wishlist persistence — ITAD's own wishlist system requires
/// OAuth2, which is real effort for a desktop app, so we keep the list
/// ourselves and just poll ITAD's key-based price API against it.
class WishlistStore {
  static const _fileName = 'wishlist.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<WishlistEntry>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return [];

    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw
          .cast<Map<String, dynamic>>()
          .map(WishlistEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<WishlistEntry> entries) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
