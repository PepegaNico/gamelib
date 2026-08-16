import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import 'epic_state.dart';

/// Shared launch logic for Epic games, used by the library grid, the
/// backlog picker and the detail screen. Prefers the native
/// `com.epicgames.launcher://` link whenever the game is actually
/// installed (see [EpicGame.isInstalled]); only falls back to the
/// legendary CLI for games legendary itself installed, and surfaces a
/// real error message when even that fails instead of doing nothing.
Future<void> launchEpicGame(BuildContext context, EpicGame game) async {
  if (!game.isInstalled && game.viaLegendary) {
    final epicState = context.read<EpicState>();
    await epicState.launch(game);
    if (epicState.lastLaunchError != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(epicState.lastLaunchError!)));
    }
    return;
  }

  final launched = await launchUrl(Uri.parse(game.primaryActionUrl));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spiel konnte nicht gestartet werden.')),
    );
  }
}
