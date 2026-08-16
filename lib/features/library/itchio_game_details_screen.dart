import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/itchio/itchio_game.dart';

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
      appBar: AppBar(title: Text(game.name)),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 460 / 215,
                  child: game.coverUrl.isEmpty
                      ? Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        )
                      : CachedNetworkImage(
                          imageUrl: game.coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if (game.classification != null)
                            Chip(
                              avatar: const Icon(
                                Icons.category_outlined,
                                size: 16,
                              ),
                              label: Text(
                                _formatClassification(game.classification!),
                              ),
                            ),
                          if (game.publishedAt != null)
                            Chip(
                              avatar: const Icon(Icons.event, size: 16),
                              label: Text(
                                'Veröffentlicht: ${_formatDate(game.publishedAt!)}',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _openStorePage,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Auf itch.io öffnen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (game.shortText != null &&
                          game.shortText!.isNotEmpty) ...[
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
                ),
              ],
            ),
          ),
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
