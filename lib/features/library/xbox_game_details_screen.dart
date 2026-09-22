import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/game_details_hero.dart';
import '../../core/xbox/xbox_game.dart';
import 'launch_game.dart';

/// Details for an Xbox app / Microsoft Store game — everything shown here
/// was already fetched from the Microsoft catalog during the library scan.
class XboxGameDetailsScreen extends StatelessWidget {
  const XboxGameDetailsScreen({super.key, required this.game});

  final XboxGame game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameDetailsHero(
              imageUrl: game.heroUrl ?? game.posterUrl ?? '',
              platform: game.platform,
              title: game.name,
              stats: [
                game.isInstalled
                    ? (Icons.check_circle_outline, 'Installiert')
                    : (Icons.cloud_outlined, 'Auf einem anderen Gerät'),
                if (game.developer != null)
                  (Icons.code_rounded, game.developer!),
              ],
              actions: [
                if (game.isInstalled)
                  FilledButton.icon(
                    onPressed: () => launchLibraryGame(context, game),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Spielen'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(game.storePageUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Store-Seite'),
                ),
              ],
            ),
            GameDetailsBody(
              children: [
                if (game.description != null && game.description!.isNotEmpty)
                  Text(
                    game.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Text(
                    'Für dieses Spiel sind keine zusätzlichen Store-Informationen verfügbar.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                Text(
                  'Xbox und der Microsoft Store geben keine Spielzeit- oder Erfolgsdaten ohne Microsoft-Login heraus.',
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
