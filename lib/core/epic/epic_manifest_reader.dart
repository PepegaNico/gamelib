import 'dart:convert';
import 'dart:io';

import 'epic_game.dart';

/// Reads the Epic Games Launcher's own local installation manifests —
/// pure local file I/O, no network call to Epic and no login required.
/// This only surfaces games currently installed via the official launcher
/// on this machine, not the user's whole purchased library.
class EpicManifestReader {
  Directory _manifestDir() {
    final programData =
        Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    return Directory('$programData\\Epic\\EpicGamesLauncher\\Data\\Manifests');
  }

  Future<List<EpicGame>> listInstalledGames() async {
    if (!Platform.isWindows) return [];

    final dir = _manifestDir();
    if (!await dir.exists()) return [];

    final games = <EpicGame>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.item')) {
        continue;
      }
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        if (json['bIsApplication'] == false) continue;
        final appName = json['AppName'] as String?;
        if (appName == null || appName.isEmpty) continue;
        games.add(EpicGame.fromManifestJson(json));
      } catch (_) {
        // Skip unreadable/unexpected manifest files rather than failing the whole scan.
      }
    }
    return games;
  }
}
