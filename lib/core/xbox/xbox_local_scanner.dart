import 'dart:convert';
import 'dart:io';

import 'xbox_game.dart';

/// Finds PC games installed through the Xbox app / Microsoft Store — pure
/// local lookup, no Microsoft login. Every such game is an MSIX package
/// that ships a `MicrosoftGame.config` (Microsoft GDK), which is what tells
/// a game apart from an ordinary Store app. Older UWP-only games without
/// that file aren't detected.
class XboxLocalScanner {
  /// Lists non-framework packages whose install folder contains a
  /// MicrosoftGame.config, with the application ids from their manifest.
  static const _script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$result = @(Get-AppxPackage | Where-Object {
  -not $_.IsFramework -and $_.InstallLocation -and
  (Test-Path (Join-Path $_.InstallLocation 'MicrosoftGame.config'))
} | ForEach-Object {
  $manifest = Get-AppxPackageManifest $_
  [PSCustomObject]@{
    family = $_.PackageFamilyName
    name = $_.Name
    location = $_.InstallLocation
    appIds = @($manifest.Package.Applications.Application | ForEach-Object { $_.Id })
  }
})
ConvertTo-Json -InputObject $result -Compress -Depth 3
''';

  Future<List<XboxGame>> listInstalledGames() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        _script,
      ], stdoutEncoding: utf8);
      if (result.exitCode != 0) return [];

      final output = (result.stdout as String).trim();
      if (output.isEmpty) return [];
      final list = (jsonDecode(output) as List).cast<Map<String, dynamic>>();

      final games = <XboxGame>[];
      for (final entry in list) {
        final family = entry['family'] as String?;
        final appIds = (entry['appIds'] as List?)?.cast<String>() ?? [];
        if (family == null || appIds.isEmpty) continue;
        games.add(
          XboxGame(
            packageFamilyName: family,
            appId: appIds.first,
            name:
                await _displayName(entry['location'] as String?) ??
                (entry['name'] as String? ?? family),
          ),
        );
      }
      return games;
    } catch (_) {
      return [];
    }
  }

  /// The game's own title from MicrosoftGame.config — unless it's a
  /// localized resource reference, which only the catalog can resolve.
  Future<String?> _displayName(String? installLocation) async {
    if (installLocation == null) return null;
    try {
      final config = await File('$installLocation\\MicrosoftGame.config')
          .readAsString();
      final match = RegExp(r'DefaultDisplayName="([^"]+)"').firstMatch(config);
      final name = match?.group(1);
      if (name == null || name.startsWith('ms-resource:')) return null;
      return name;
    } catch (_) {
      return null;
    }
  }
}
