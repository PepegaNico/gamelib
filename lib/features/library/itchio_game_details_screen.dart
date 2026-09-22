import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/itchio/itchio_game.dart';
import '../../core/widgets/game_details_hero.dart';

/// Mirrors [GameDetailsScreen]'s layout — unlike Epic, itch.io's owned-keys
/// response already includes a real description/classification/release
/// date directly, so there's no lazy fetch step here, just no playtime or
/// achievements since the API doesn't track those at all.
class ItchioGameDetailsScreen extends StatelessWidget {
  const ItchioGameDetailsScreen({super.key, required this.game});

  final ItchioGame game;

  Future<void> _openStorePage() async {
    await launchUrl(
      Uri.parse(game.pageUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  String _formatClassification(String value) => switch (value) {
    'game' => 'Spiel',
    'tool' => 'Tool',
    'assets' => 'Assets',
    'game_mod' => 'Mod',
    'physical_game' => 'Physisches Spiel',
    'soundtrack' => 'Soundtrack',
    'other' => 'Sonstiges',
    'comic' => 'Comic',
    'book' => 'Buch',
    _ => value,
  };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameDetailsHero(
              imageUrl: game.coverUrl,
              platform: game.platform,
              title: game.name,
              stats: [
                if (game.classification != null)
                  (
                    Icons.category_outlined,
                    _formatClassification(game.classification!),
                  ),
                if (game.publishedAt != null)
                  (
                    Icons.event,
                    'Veröffentlicht ${_formatDate(game.publishedAt!)}',
                  ),
              ],
              actions: [
                FilledButton.icon(
                  onPressed: _openStorePage,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Auf itch.io öffnen'),
                ),
              ],
            ),
            GameDetailsBody(
              children: [
                if (game.shortText != null && game.shortText!.isNotEmpty) ...[
                  Text(
                    game.shortText!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if (game.author.isNotEmpty)
                  _InfoRow(label: 'Entwickler', value: game.author),
                const SizedBox(height: 8),
                Text(
                  'itch.io bietet keine Spielzeit- oder Erfolgsdaten über die API an.',
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
