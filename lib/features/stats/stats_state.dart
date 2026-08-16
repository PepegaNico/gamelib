import 'package:flutter/foundation.dart';

import '../../core/stats/playtime_history_store.dart';
import '../../core/stats/playtime_snapshot.dart';
import '../../core/steam/steam_game.dart';

class _DailyPlay {
  final DateTime date;
  final String gameId;
  final String gameName;
  final int deltaMinutes;

  _DailyPlay({
    required this.date,
    required this.gameId,
    required this.gameName,
    required this.deltaMinutes,
  });
}

/// Turns the raw per-day cumulative-playtime snapshots into "hours played
/// on day X" by diffing consecutive snapshots per game. The very first
/// snapshot recorded for a game can't be attributed to a specific day (no
/// prior baseline), so it contributes nothing — this is why the picture
/// only gets meaningful after the app has been used for a while.
class StatsState extends ChangeNotifier {
  StatsState({PlaytimeHistoryStore? store})
    : _store = store ?? PlaytimeHistoryStore();

  final PlaytimeHistoryStore _store;

  List<PlaytimeSnapshot> _snapshots = [];
  List<_DailyPlay> _dailyPlays = [];
  bool isLoading = true;

  Future<void> load() async {
    _snapshots = await _store.loadAll();
    _recompute();
    isLoading = false;
    notifyListeners();
  }

  Future<void> recordSnapshot(List<SteamGame> games) async {
    await _store.recordSnapshot(games);
    _snapshots = await _store.loadAll();
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    final byGame = <String, List<PlaytimeSnapshot>>{};
    for (final snapshot in _snapshots) {
      byGame.putIfAbsent(snapshot.gameId, () => []).add(snapshot);
    }

    final plays = <_DailyPlay>[];
    for (final entries in byGame.values) {
      entries.sort((a, b) => a.date.compareTo(b.date));
      for (var i = 1; i < entries.length; i++) {
        final delta =
            entries[i].playtimeMinutes - entries[i - 1].playtimeMinutes;
        if (delta <= 0) continue;
        plays.add(
          _DailyPlay(
            date: entries[i].date,
            gameId: entries[i].gameId,
            gameName: entries[i].gameName,
            deltaMinutes: delta,
          ),
        );
      }
    }
    _dailyPlays = plays;
  }

  int get distinctDaysRecorded => _snapshots.map((s) => s.date).toSet().length;

  /// Need at least a few distinct recorded days before day-to-day deltas
  /// are meaningful rather than just noise/coincidence.
  bool get hasEnoughData => distinctDaysRecorded >= 3;

  /// Oldest → newest, always exactly 7 entries (zero-filled).
  List<MapEntry<DateTime, double>> get dailyHoursLast7Days {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final byDay = <DateTime, double>{};
    for (final play in _dailyPlays) {
      byDay.update(
        play.date,
        (v) => v + play.deltaMinutes / 60,
        ifAbsent: () => play.deltaMinutes / 60,
      );
    }

    return [
      for (var i = 6; i >= 0; i--)
        MapEntry(
          todayKey.subtract(Duration(days: i)),
          byDay[todayKey.subtract(Duration(days: i))] ?? 0,
        ),
    ];
  }

  double get weeklyTotalHours =>
      dailyHoursLast7Days.fold(0, (sum, e) => sum + e.value);

  List<MapEntry<String, double>> topGamesThisYear({int limit = 5}) {
    final currentYear = DateTime.now().year;
    final byGame = <String, double>{};
    for (final play in _dailyPlays) {
      if (play.date.year != currentYear) continue;
      byGame.update(
        play.gameName,
        (v) => v + play.deltaMinutes / 60,
        ifAbsent: () => play.deltaMinutes / 60,
      );
    }
    final sorted = byGame.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  double get totalHoursThisYear {
    final currentYear = DateTime.now().year;
    return _dailyPlays
        .where((p) => p.date.year == currentYear)
        .fold(0, (sum, p) => sum + p.deltaMinutes / 60);
  }
}
