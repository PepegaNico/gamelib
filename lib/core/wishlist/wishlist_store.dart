import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'wishlist_entry.dart';

/// Local-only wishlist persistence — ITAD's own wishlist system requires
/// OAuth2, which is real effort for a desktop app, so we keep the list
/// ourselves and just poll ITAD's key-based price API against it.
///
/// Stores an `updatedAt` timestamp alongside the entries so Cloud-Sync can
/// do last-write-wins between devices (see SyncState.sync) — a plain
/// union-merge would never let a deleted entry actually disappear.
class WishlistStore {
  static const _fileName = 'wishlist.json';
  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<({List<WishlistEntry> entries, DateTime updatedAt})> load() async {
    final file = await _file();
    if (!await file.exists()) return (entries: <WishlistEntry>[], updatedAt: _epoch);

    try {
      final decoded = jsonDecode(await file.readAsString());
      // Back-compat: the pre-sync format was a plain JSON array of entries.
      if (decoded is List) {
        return (
          entries: decoded
              .cast<Map<String, dynamic>>()
              .map(WishlistEntry.fromJson)
              .toList(),
          updatedAt: _epoch,
        );
      }
      final map = decoded as Map<String, dynamic>;
      final entries = (map['entries'] as List)
          .cast<Map<String, dynamic>>()
          .map(WishlistEntry.fromJson)
          .toList();
      final updatedAt =
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? _epoch;
      return (entries: entries, updatedAt: updatedAt);
    } catch (_) {
      return (entries: <WishlistEntry>[], updatedAt: _epoch);
    }
  }

  /// Persists entries changed locally just now — stamps the current time.
  /// Returns that timestamp so the caller can track it without re-reading.
  Future<DateTime> saveAll(List<WishlistEntry> entries) async {
    final updatedAt = DateTime.now().toUtc();
    await _write(entries, updatedAt);
    return updatedAt;
  }

  /// Persists entries adopted from another device via Cloud-Sync — keeps
  /// that device's own timestamp instead of stamping "now", so later sync
  /// comparisons stay correct.
  Future<void> replaceAll(List<WishlistEntry> entries, DateTime updatedAt) =>
      _write(entries, updatedAt);

  Future<void> _write(List<WishlistEntry> entries, DateTime updatedAt) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'updatedAt': updatedAt.toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      }),
    );
  }
}
