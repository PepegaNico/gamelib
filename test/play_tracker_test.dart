import 'package:flutter_test/flutter_test.dart';
import 'package:gamelib/core/epic/epic_game.dart';
import 'package:gamelib/core/playtracking/play_history_store.dart';
import 'package:gamelib/core/playtracking/play_tracker.dart';

class _MemoryStore extends PlayHistoryStore {
  Map<String, PlayRecord> saved = {};

  @override
  Future<Map<String, PlayRecord>> load() async => saved;

  @override
  Future<void> save(Map<String, PlayRecord> history) async =>
      saved = Map.of(history);
}

EpicGame _epic(String appName, String? dir) => EpicGame(
  appName: appName,
  name: appName,
  namespace: null,
  catalogItemId: null,
  isInstalled: true,
  installLocation: dir,
);

void main() {
  test('credits a minute to the game whose folder has a running exe, '
      'and reports when it stops', () async {
    var running = <String>{
      r'c:\program files\epic games\fortnite\fortnitegame\binaries\win64\fortniteclient-win64-shipping.exe',
      r'c:\windows\explorer.exe',
    };
    final store = _MemoryStore();
    final tracker = PlayTracker(
      store: store,
      listRunningExecutables: () => running,
    );
    await tracker.loadForTesting();

    final fortnite = _epic('Fortnite', r'C:\Program Files\Epic Games\Fortnite');
    // Same prefix, different folder — must not match.
    final tools = _epic(
      'FortniteTools',
      r'C:\Program Files\Epic Games\FortniteTools',
    );
    // A drive root would match everything — must be ignored.
    final root = _epic('Broken', r'C:\');
    tracker.watch([fortnite, tools, root]);

    var ended = 0;
    tracker.onSessionEnded = () => ended++;

    await tracker.tick();
    await tracker.tick();
    expect(fortnite.trackedMinutes, 2);
    expect(fortnite.lastPlayed, isNotNull);
    expect(fortnite.hasPlaytimeData, isTrue);
    expect(tools.trackedMinutes, 0);
    expect(root.trackedMinutes, 0);
    expect(store.saved['epic:Fortnite']?.minutes, 2);
    expect(ended, 0);

    running = {r'c:\windows\explorer.exe'};
    await tracker.tick();
    expect(ended, 1);
    expect(fortnite.trackedMinutes, 2);

    // After a library refresh the game objects are new — history re-applies.
    final refreshed = _epic(
      'Fortnite',
      r'C:\Program Files\Epic Games\Fortnite',
    );
    tracker.watch([refreshed]);
    expect(refreshed.trackedMinutes, 2);
  });

  test('synced Epic games carry play data to other devices', () {
    final game = _epic('Fortnite', r'C:\Games\Fortnite')
      ..applyTrackedPlay(lastPlayed: DateTime(2026, 9, 27, 20), minutes: 95);
    final copy = EpicGame.fromSyncJson(game.toSyncJson());
    expect(copy.trackedMinutes, 95);
    expect(copy.lastPlayed, DateTime(2026, 9, 27, 20));
    expect(copy.installDirectory, isNull); // not installed on the other device
  });
}
