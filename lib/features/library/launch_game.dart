import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import '../../core/models/library_game.dart';
import '../../core/xbox/xbox_game.dart';
import '../epic/epic_launch.dart';

/// Starts [game] the right way for its store — Epic and Xbox need more
/// than a plain URL — and shows a snackbar if that fails.
Future<void> launchLibraryGame(BuildContext context, LibraryGame game) async {
  if (game is EpicGame) {
    await launchEpicGame(context, game);
    return;
  }

  final launched = game is XboxGame && game.isInstalled
      ? await game.launch()
      : await launchUrl(Uri.parse(game.primaryActionUrl));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${game.primaryActionLabel} fehlgeschlagen.')),
    );
  }
}
