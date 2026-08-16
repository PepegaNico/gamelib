import 'dart:convert';
import 'dart:io';

import 'epic_game.dart';

class LegendaryStatus {
  final String username;
  final int gamesAvailable;

  LegendaryStatus({required this.username, required this.gamesAvailable});
}

/// Drives the community-maintained `legendary` CLI (legendary-gl/legendary)
/// instead of reimplementing Epic's unofficial API ourselves. Requires the
/// user to install it separately and authenticate once via a terminal
/// (`legendary auth --import` if the official Epic launcher is already
/// logged in, or `legendary auth` for a manual browser login) — that flow
/// can't be driven from inside this app.
class LegendaryCliService {
  Future<bool> isAvailable() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('legendary', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<LegendaryStatus?> getStatus() async {
    try {
      final result = await Process.run('legendary', ['status', '--json']);
      if (result.exitCode != 0) return null;

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final username = json['account'] as String?;
      if (username == null ||
          username.isEmpty ||
          username.toLowerCase().contains('not logged in')) {
        return null;
      }
      return LegendaryStatus(
        username: username,
        gamesAvailable: (json['games_available'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<EpicGame>> listOwnedGames() async {
    try {
      final result = await Process.run('legendary', ['list', '--json']);
      if (result.exitCode != 0) return [];

      final list = jsonDecode(result.stdout as String) as List;
      return list
          .cast<Map<String, dynamic>>()
          .where((g) => g['is_dlc'] != true)
          .map(EpicGame.fromLegendaryJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns an error message if legendary rejects the launch outright
  /// (e.g. "not currently installed"), or null on apparent success. Games
  /// that actually start keep running under legendary's supervision after
  /// this returns — we only wait briefly to catch immediate failures, not
  /// for the game itself to exit.
  Future<String?> launch(String appName) async {
    try {
      final process = await Process.start('legendary', ['launch', appName]);
      final stderrBuffer = StringBuffer();
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen(stderrBuffer.write);

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 4),
        onTimeout: () => 0,
      );
      if (exitCode == 0) return null;

      final message = stderrBuffer.toString().trim();
      return message.isNotEmpty
          ? message
          : 'Legendary hat den Start abgelehnt (Code $exitCode).';
    } catch (e) {
      return 'Legendary konnte nicht ausgeführt werden: $e';
    }
  }
}
