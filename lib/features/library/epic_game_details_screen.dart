import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import '../../core/epic/epic_store_api_service.dart';
import '../../core/widgets/game_details_hero.dart';
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameDetailsHero(
              imageUrl: game.headerImageUrl,
              platform: game.platform,
              title: game.name,
              stats: [
                game.isInstalled
                    ? (Icons.check_circle_outline, 'Installiert')
                    : (Icons.cloud_outlined, 'Nicht installiert'),
                if (game.resolvedDeveloper != null)
                  (Icons.code_rounded, game.resolvedDeveloper!),
              ],
              actions: [
                FilledButton.icon(
                  onPressed: _launch,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Spielen'),
                ),
                OutlinedButton.icon(
                  onPressed: _openStorePage,
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
          ],
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
