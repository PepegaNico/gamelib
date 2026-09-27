import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/library_game.dart';
import 'play_history_store.dart';
import 'running_processes.dart';
import 'trackable_game.dart';

/// Records "last played" and playtime for installed games whose stores
/// don't report it (Epic, Xbox / Microsoft Store): once a minute it checks
/// which programs are running and credits a minute to every game with a
/// process inside its install folder. Only counts while GameZer runs (it
/// stays in the tray), from the first launch of this feature onwards.
class PlayTracker extends ChangeNotifier {
  PlayTracker({
    PlayHistoryStore? store,
    Set<String> Function()? listRunningExecutables,
  }) : _store = store ?? PlayHistoryStore(),
       _listRunning = listRunningExecutables ?? runningExecutablePaths;

  static const _interval = Duration(minutes: 1);

  final PlayHistoryStore _store;
  final Set<String> Function() _listRunning;
  Map<String, PlayRecord> _history = {};
  List<TrackableGame> _games = [];
  Set<String> _running = {};
  Timer? _timer;
  bool _loaded = false;

  /// Called when a tracked game stops running — used to push the new play
  /// data to Cloud-Sync right away.
  VoidCallback? onSessionEnded;

  Set<String> get runningGameIds => _running;

  Future<void> start() async {
    if (!Platform.isWindows || _timer != null) return;
    _history = await _store.load();
    _loaded = true;
    _applyAll();
    _timer = Timer.periodic(_interval, (_) => tick());
  }

  /// Loads the saved history without starting the timer (tests).
  @visibleForTesting
  Future<void> loadForTesting() async {
    _history = await _store.load();
    _loaded = true;
    _applyAll();
  }

  /// Sets the games to watch (call after every library refresh — the game
  /// objects are recreated then) and fills in their recorded play data.
  void watch(Iterable<LibraryGame> games) {
    _games = games
        .whereType<TrackableGame>()
        .where((g) => _normalizedDir(g.installDirectory) != null)
        .toList();
    if (_loaded) _applyAll();
  }

  void _applyAll() {
    for (final game in _games) {
      final record = _history[game.id];
      if (record != null) {
        game.applyTrackedPlay(
          lastPlayed: record.lastPlayed,
          minutes: record.minutes,
        );
      }
    }
  }

  /// One polling step; runs every [_interval] once [start]ed.
  @visibleForTesting
  Future<void> tick() async {
    if (_games.isEmpty) return;
    final paths = _listRunning();
    final now = DateTime.now();
    final running = <String>{};

    for (final game in _games) {
      final dir = _normalizedDir(game.installDirectory)!;
      if (!paths.any((p) => p.startsWith(dir))) continue;
      running.add(game.id);
      final record =
          _history.putIfAbsent(game.id, () => PlayRecord(lastPlayed: now))
            ..lastPlayed = now
            ..minutes += _interval.inMinutes;
      game.applyTrackedPlay(
        lastPlayed: record.lastPlayed,
        minutes: record.minutes,
      );
    }

    final ended = _running.difference(running);
    _running = running;
    if (running.isNotEmpty || ended.isNotEmpty) {
      await _store.save(_history);
      notifyListeners();
    }
    if (ended.isNotEmpty) onSessionEnded?.call();
  }

  /// Lower-case, backslash-separated, with a trailing separator so
  /// "…\Fortnite" doesn't also match "…\FortniteTools". Drive roots and
  /// other too-short paths are rejected so they can't match everything.
  static String? _normalizedDir(String? dir) {
    if (dir == null || dir.trim().isEmpty) return null;
    var normalized = dir.trim().replaceAll('/', r'\').toLowerCase();
    if (!normalized.endsWith(r'\')) normalized = '$normalized\\';
    final depth = normalized.split(r'\').where((s) => s.isNotEmpty).length;
    return depth >= 2 ? normalized : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
