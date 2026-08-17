import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/itad/itad_api_service.dart';
import '../../core/itad/itad_models.dart';
import '../../core/steam/steam_account.dart';
import '../../core/steam/steam_achievement.dart';
import '../../core/steam/steam_app_details.dart';
import '../../core/steam/steam_game.dart';
import '../../core/steam/steam_store_api_service.dart';
import '../../core/steam/steam_web_api_service.dart';
import '../auth/auth_state.dart';
import '../wishlist/wishlist_state.dart';
import 'achievements_section.dart';

class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({super.key, required this.game});

  final SteamGame game;

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  final _storeApi = SteamStoreApiService();
  final _webApi = SteamWebApiService();
  final _itadApi = ItadApiService();
  SteamAppDetails? _details;
  bool _loading = true;
  List<SteamAchievement>? _achievements;
  bool _loadingAchievements = true;
  ItadPriceInfo? _priceInfo;
  bool _loadingPrice = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadAchievements();
    _loadPrice();
  }

  Future<void> _load() async {
    final details = await _storeApi.getAppDetails(widget.game.appId);
    if (!mounted) return;
    setState(() {
      _details = details;
      _loading = false;
    });
  }

  Future<void> _loadAchievements() async {
    final auth = context.read<AuthState>();
    SteamAccount? owningAccount = auth.primaryAccount;
    for (final a in auth.accounts) {
      if (a.steamId == widget.game.steamId) {
        owningAccount = a;
        break;
      }
    }
    if (owningAccount == null) {
      setState(() => _loadingAchievements = false);
      return;
    }

    final achievements = await _webApi.getAchievements(
      apiKey: owningAccount.apiKey,
      steamId: owningAccount.steamId,
      appId: widget.game.appId,
    );
    if (!mounted) return;
    setState(() {
      _achievements = achievements;
      _loadingAchievements = false;
    });
  }

  Future<void> _loadPrice() async {
    final wishlist = context.read<WishlistState>();
    if (!wishlist.isConnected) return;

    setState(() => _loadingPrice = true);
    final match = await _itadApi.lookupBySteamAppId(
      wishlist.apiKey!,
      widget.game.appId,
    );
    if (match == null) {
      if (mounted) setState(() => _loadingPrice = false);
      return;
    }
    final prices = await _itadApi.getPrices(wishlist.apiKey!, [match.id]);
    if (!mounted) return;
    setState(() {
      _priceInfo = prices[match.id];
      _loadingPrice = false;
    });
  }

  Future<void> _launchGame() async {
    final launched = await launchUrl(Uri.parse(widget.game.launchUrl));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Steam konnte nicht geöffnet werden. Ist Steam installiert?',
          ),
        ),
      );
    }
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
                  child: CachedNetworkImage(
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
                          _StatChip(
                            icon: Icons.schedule,
                            label:
                                '${game.playtimeForeverHours.toStringAsFixed(1)} h gesamt',
                          ),
                          if (game.lastPlayed != null)
                            _StatChip(
                              icon: Icons.event,
                              label:
                                  'Zuletzt gespielt: ${_formatDate(game.lastPlayed!)}',
                            ),
                          if (!_loading && _details?.metacriticScore != null)
                            _StatChip(
                              icon: Icons.star,
                              label: 'Metacritic ${_details!.metacriticScore}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _launchGame,
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
                      else if (_details == null)
                        Text(
                          'Für dieses Spiel sind keine zusätzlichen Store-Informationen verfügbar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        _DetailsBody(details: _details!),
                      const SizedBox(height: 8),
                      if (_loadingAchievements)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_achievements != null &&
                          _achievements!.isNotEmpty)
                        AchievementsSection(achievements: _achievements!),
                      if (_loadingPrice || _priceInfo != null) ...[
                        const SizedBox(height: 16),
                        _PriceSection(
                          priceInfo: _priceInfo,
                          isLoading: _loadingPrice,
                        ),
                      ],
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

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.details});

  final SteamAppDetails details;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.genres.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final genre in details.genres) Chip(label: Text(genre)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (details.shortDescription != null &&
            details.shortDescription!.isNotEmpty) ...[
          Text(
            details.shortDescription!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
        ],
        if (details.developers.isNotEmpty)
          _InfoRow(label: 'Entwickler', value: details.developers.join(', ')),
        if (details.publishers.isNotEmpty)
          _InfoRow(label: 'Publisher', value: details.publishers.join(', ')),
        if (details.releaseDate != null)
          _InfoRow(label: 'Release', value: details.releaseDate!),
        if (details.fullControllerSupport)
          const _InfoRow(
            label: 'Controller',
            value: 'Volle Controller-Unterstützung',
          ),
        if (details.screenshotUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: details.screenshotUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: details.screenshotUrls[index],
                  width: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
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

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.priceInfo, required this.isLoading});

  final ItadPriceInfo? priceInfo;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final info = priceInfo;
    if (info == null || info.deals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preise', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final deal in info.deals.take(5))
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(deal.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(deal.shopName)),
                  if (deal.cutPercent > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text('-${deal.cutPercent}%'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Text(
                    deal.price.formatted,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        if (info.historyLowAll != null) ...[
          const SizedBox(height: 4),
          Text(
            'Tiefstpreis aller Zeiten: ${info.historyLowAll!.formatted}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}
