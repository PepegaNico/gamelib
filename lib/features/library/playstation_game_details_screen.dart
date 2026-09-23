import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/playstation/playstation_game.dart';
import '../../core/widgets/game_details_hero.dart';

/// Details for a PS4/PS5 game from the connected PlayStation account.
class PlaystationGameDetailsScreen extends StatelessWidget {
  const PlaystationGameDetailsScreen({super.key, required this.game});

  final PlaystationGame game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameDetailsHero(
              imageUrl: game.heroUrl ?? '',
              fallbackImageUrl: game.iconUrl,
              platform: game.platform,
              title: game.name,
              stats: [
                (Icons.videogame_asset_outlined, game.consoleLabel),
                if (game.hasBeenPlayed)
                  (
                    Icons.schedule,
                    '${game.playtimeForeverHours.toStringAsFixed(1)} h gespielt',
                  ),
                if (game.lastPlayed != null)
                  (Icons.event, 'Zuletzt ${_formatDate(game.lastPlayed!)}'),
              ],
              actions: [
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(game.storePageUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Im PlayStation Store'),
                ),
              ],
            ),
            GameDetailsBody(
              children: [
                Text(
                  'Konsolenspiele lassen sich nicht vom PC aus starten. '
                  'Spielzeit und letztes Spieldatum kommen von deinem '
                  'PlayStation-Konto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
