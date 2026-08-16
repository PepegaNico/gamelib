import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import '../../core/epic/epic_store_api_service.dart';
import '../epic/epic_launch.dart';

/// Mirrors [GameDetailsScreen]'s layout as closely as Epic's much thinner
/// public data allows: no playtime, no achievements, no metacritic — but
/// the same header/stats/description/genre-chip structure.
class EpicGameDetailsScreen extends StatefulWidget {
  const EpicGameDetailsScreen({super.key, required this.game});

  final EpicGame game;

  @override
  State<EpicGameDetailsScreen> createState() => _EpicGameDetailsScreenState();
}

class _EpicGameDetailsScreenState extends State<EpicGameDetailsScreen> {
  final _storeApi = EpicStoreApiService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.game.storeDetailsFetched) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final listing = await _storeApi.findByTitle(widget.game.name);
    if (listing != null) widget.game.applyStoreListing(listing);
    widget.game.storeDetailsFetched = true;
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _launch() async {
    await launchEpicGame(context, widget.game);
  }

  Future<void> _openStorePage() async {
    await launchUrl(
      Uri.parse(widget.game.storePageUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

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
                  child: game.headerImageUrl.isEmpty
                      ? Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        )
                      : CachedNetworkImage(
                          imageUrl: game.headerImageUrl,
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
                          Chip(
                            avatar: Icon(
                              game.isInstalled
                                  ? Icons.check_circle_outline
                                  : Icons.cloud_outlined,
                              size: 16,
                            ),
                            label: Text(
                              game.isInstalled
                                  ? 'Installiert'
                                  : 'Über Legendary bekannt, nicht installiert',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _launch,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Spiel starten'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _openStorePage,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Store-Seite öffnen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (game.resolvedDescription == null &&
                          game.resolvedDeveloper == null &&
                          game.resolvedCategories.isEmpty)
                        Text(
                          'Für dieses Spiel sind keine zusätzlichen Store-Informationen verfügbar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        _DetailsBody(game: game),
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

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.game});

  final EpicGame game;

  /// Epic only exposes generic store taxonomy paths like
  /// "games/edition/base", not real genre names — this turns the last,
  /// most specific segment into something presentable.
  String _formatCategory(String path) {
    final segment = path.split('/').last;
    if (segment.isEmpty) return path;
    return segment[0].toUpperCase() + segment.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final categories = game.resolvedCategories
        .map(_formatCategory)
        .where((c) => !['Games', 'Applications', 'Edition'].contains(c))
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final category in categories) Chip(label: Text(category)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (game.resolvedDescription != null &&
            game.resolvedDescription!.isNotEmpty) ...[
          Text(
            game.resolvedDescription!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
        ],
        if (game.resolvedDeveloper != null)
          _InfoRow(label: 'Entwickler', value: game.resolvedDeveloper!),
      ],
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
