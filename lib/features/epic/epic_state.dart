import 'package:flutter/foundation.dart';

import '../../core/epic/epic_game.dart';
import '../../core/epic/epic_manifest_reader.dart';
import '../../core/epic/legendary_cli_service.dart';

class EpicState extends ChangeNotifier {
  EpicState({
    LegendaryCliService? legendary,
    EpicManifestReader? manifestReader,
  }) : _legendary = legendary ?? LegendaryCliService(),
       _manifestReader = manifestReader ?? EpicManifestReader();

  final LegendaryCliService _legendary;
  final EpicManifestReader _manifestReader;

  List<EpicGame> games = [];
  bool isLoading = false;

  bool legendaryAvailable = false;
  bool legendaryAuthenticated = false;
  String? legendaryUsername;

  /// True once a scan has completed, so the UI can distinguish "no Epic
  /// games" from "haven't checked yet".
  bool hasScanned = false;

  /// The most recent error from a launch attempt, so the UI can show it
  /// instead of silently doing nothing.
  String? lastLaunchError;

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();

    legendaryAvailable = await _legendary.isAvailable();
    if (legendaryAvailable) {
      final status = await _legendary.getStatus();
      legendaryAuthenticated = status != null;
      legendaryUsername = status?.username;
    } else {
      legendaryAuthenticated = false;
      legendaryUsername = null;
    }

    // Always scan the local manifests too — even when Legendary is the
    // primary source, it only knows about installs it manages itself, not
    // ones made through the real Epic Games Launcher. Cross-referencing by
    // namespace+catalogItemId lets us prefer the reliable native launch
    // link for anything actually installed, and fall back to the
    // legendary CLI only for games it doesn't know are installed.
    final manifestGames = await _manifestReader.listInstalledGames();

    if (legendaryAuthenticated) {
      final installedByKey = {
        for (final g in manifestGames)
          if (g.namespace != null && g.catalogItemId != null)
            '${g.namespace}:${g.catalogItemId}': g,
      };

      final owned = await _legendary.listOwnedGames();
      for (final game in owned) {
        final installed =
            installedByKey['${game.namespace}:${game.catalogItemId}'];
        if (installed != null) {
          game.isInstalled = true;
          game.installedAppName = installed.installedAppName;
        }
      }
      games = owned;
    } else {
      games = manifestGames;
    }

    hasScanned = true;
    isLoading = false;
    notifyListeners();
  }

  Future<void> launch(EpicGame game) async {
    lastLaunchError = null;
    if (!game.isInstalled && game.viaLegendary) {
      lastLaunchError = await _legendary.launch(game.appName);
      notifyListeners();
    }
  }
}
