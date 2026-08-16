import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../steam/steam_game.dart';
import 'playtime_snapshot.dart';

/// Persists one playtime snapshot per (game, day) as a flat JSON file —
/// no server, no database engine, just enough to build up a local history
/// over time since Steam's API only ever reports the current cumulative
/// total, never a day-by-day breakdown.
class PlaytimeHistoryStore {
  static const _fileName = 'playtime_history.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<PlaytimeSnapshot>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return [];

    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw
          .cast<Map<String, dynamic>>()
          .map(PlaytimeSnapshot.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<PlaytimeSnapshot> snapshots) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(snapshots.map((s) => s.toJson()).toList()),
    );
  }

  /// Upserts today's entry for each game — safe to call on every refresh,
  /// won't create duplicate rows for the same day.
  Future<void> recordSnapshot(List<SteamGame> games) async {
    if (games.isEmpty) return;

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final existing = await loadAll();
    final byKey = {
      for (final s in existing) '${s.gameId}|${s.date.toIso8601String()}': s,
    };

    for (final game in games) {
      final key = '${game.appId}|${todayKey.toIso8601String()}';
      byKey[key] = PlaytimeSnapshot(
        gameId: '${game.appId}',
        gameName: game.name,
        playtimeMinutes: game.playtimeForeverMinutes,
        date: todayKey,
      );
    }

    await _saveAll(byKey.values.toList());
  }
}
