import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import '../../core/epic/epic_store_api_service.dart';
import '../../core/epic/epic_store_listing.dart';
import '../../core/models/game_platform.dart';
import '../../core/steam/steam_store_api_service.dart';
import '../../core/steam/steam_store_listing.dart';
import '../../core/steam/steam_store_search_service.dart';
import '../../core/widgets/hover_lift.dart';
import '../library/library_state.dart';

/// Unifies Epic and Steam store search/browse results so both can be shown
/// (and filtered) in one grid despite their APIs returning very different
/// shapes.
class _StoreResult {
  final GamePlatform platform;
  final String title;
  final String? imageUrl;
  final String? price;
  final String? originalPrice;
  final bool isOnSale;
  final String url;
  final bool isOwned;

  /// Steam-only — used to classify game/dlc/demo and pull genres after the
  /// fact (Steam's search/deals endpoints don't include either, only
  /// appdetails does — see [SteamStoreApiService.getAppDetails]). Null/empty
  /// while unclassified or for non-Steam results.
  final int? steamAppId;
  String? contentType;
  List<String> genres = [];

  _StoreResult({
    required this.platform,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.originalPrice,
    required this.isOnSale,
    required this.url,
    required this.isOwned,
    this.steamAppId,
  });

  bool get isDlc => contentType == 'dlc';
  bool get isDemo => contentType == 'demo';
}

class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  static const _classifyConcurrency = 8;

  final _epicApi = EpicStoreApiService();
  final _steamApi = SteamStoreSearchService();
  final _steamDetailsApi = SteamStoreApiService();
  final _controller = TextEditingController();

  List<_StoreResult> _results = [];
  final Set<GamePlatform> _selectedStores = {
    GamePlatform.steam,
    GamePlatform.epic,
  };
  final Set<String> _selectedGenres = {};
  bool _showDlc = false;
  bool _showDemos = false;
  bool _isLoading = false;
  String? _currentQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeals());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isOwned(GamePlatform platform, String title, {int? steamAppId}) {
    final library = context.read<LibraryState>();
    if (platform == GamePlatform.steam) {
      return library.steamGames.any((g) => g.appId == steamAppId);
    }
    return library.games.whereType<EpicGame>().any(
      (g) => g.name.toLowerCase() == title.toLowerCase(),
    );
  }

  Future<void> _loadDeals() async {
    setState(() {
      _isLoading = true;
      _currentQuery = null;
    });
    await _runFetch(
      epicFetch: _epicApi.getDeals,
      steamFetch: _steamApi.getDeals,
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      await _loadDeals();
      return;
    }
    setState(() {
      _isLoading = true;
      _currentQuery = query.trim();
    });
    await _runFetch(
      epicFetch: () => _epicApi.search(query),
      steamFetch: () => _steamApi.search(query),
    );
  }

  _StoreResult _fromEpicListing(EpicStoreListing l) => _StoreResult(
    platform: GamePlatform.epic,
    title: l.title,
    imageUrl: l.imageUrl,
    price: l.formattedPrice,
    originalPrice: l.formattedOriginalPrice,
    isOnSale: l.isOnSale,
    url: l.storeUrl,
    isOwned: _isOwned(GamePlatform.epic, l.title),
  );

  _StoreResult _fromSteamListing(SteamStoreListing l) => _StoreResult(
    platform: GamePlatform.steam,
    title: l.name,
    imageUrl: l.imageUrl,
    price: l.formattedPrice,
    originalPrice: l.formattedOriginalPrice,
    isOnSale: l.isOnSale,
    url: l.storeUrl,
    steamAppId: l.appId,
    isOwned: _isOwned(GamePlatform.steam, l.name, steamAppId: l.appId),
  );

  Future<void> _runFetch({
    required Future<List<EpicStoreListing>> Function() epicFetch,
    required Future<List<SteamStoreListing>> Function() steamFetch,
  }) async {
    final results = <_StoreResult>[];
    final futures = <Future<void>>[];

    if (_selectedStores.contains(GamePlatform.epic)) {
      futures.add(
        epicFetch().then(
          (listings) => results.addAll(listings.map(_fromEpicListing)),
        ),
      );
    }
    List<_StoreResult> steamResults = [];
    if (_selectedStores.contains(GamePlatform.steam)) {
      futures.add(
        steamFetch().then((listings) {
          steamResults = listings.map(_fromSteamListing).toList();
          results.addAll(steamResults);
        }),
      );
    }

    await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });

    unawaited(_classifySteamResults(steamResults));
  }

  /// Neither Steam's search nor its deals endpoint includes genres or a
  /// game/dlc/demo classification — both need a per-app appdetails lookup,
  /// done here in the background so the initial results show up immediately.
  Future<void> _classifySteamResults(List<_StoreResult> steamResults) async {
    for (var i = 0; i < steamResults.length; i += _classifyConcurrency) {
      final batch = steamResults.sublist(
        i,
        (i + _classifyConcurrency).clamp(0, steamResults.length),
      );
      final details = await Future.wait(
        batch.map((r) => _steamDetailsApi.getAppDetails(r.steamAppId!)),
      );
      for (var j = 0; j < batch.length; j++) {
        batch[j].contentType = details[j]?.type;
        batch[j].genres = details[j]?.genres ?? [];
      }
      if (mounted) setState(() {});
    }
  }

  List<_StoreResult> get _visibleResults => _results.where((r) {
    if (r.isDlc && !_showDlc) return false;
    if (r.isDemo && !_showDemos) return false;
    if (_selectedGenres.isNotEmpty && !r.genres.any(_selectedGenres.contains)) {
      return false;
    }
    return true;
  }).toList();

  Set<String> get _availableGenres => _results.expand((r) => r.genres).toSet();

  @override
  Widget build(BuildContext context) {
    final visible = _visibleResults;
    final genres = _availableGenres;

    return Scaffold(
      appBar: AppBar(title: const Text('Store durchsuchen')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              onSubmitted: _search,
              onChanged: (value) {
                if (value.trim().isEmpty && _currentQuery != null) _loadDeals();
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Spiele im Epic Store und Steam Shop suchen…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _search(_controller.text),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _currentQuery == null
                    ? 'Angebote'
                    : 'Suchergebnisse für "$_currentQuery"',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final store in [GamePlatform.steam, GamePlatform.epic])
                  FilterChip(
                    avatar: Icon(store.icon, size: 16),
                    label: Text(store.label),
                    selected: _selectedStores.contains(store),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedStores.add(store);
                      } else if (_selectedStores.length > 1) {
                        _selectedStores.remove(store);
                      }
                    }),
                  ),
                if (_selectedStores.contains(GamePlatform.steam)) ...[
                  FilterChip(
                    label: const Text('DLC anzeigen'),
                    selected: _showDlc,
                    onSelected: (selected) =>
                        setState(() => _showDlc = selected),
                  ),
                  FilterChip(
                    label: const Text('Demos anzeigen'),
                    selected: _showDemos,
                    onSelected: (selected) =>
                        setState(() => _showDemos = selected),
                  ),
                ],
              ],
            ),
          ),
          if (genres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final genre in genres.toList()..sort())
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(genre),
                          selected: _selectedGenres.contains(genre),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedGenres.add(genre);
                            } else {
                              _selectedGenres.remove(genre);
                            }
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  Widget _buildBody(List<_StoreResult> visible) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _results.isEmpty
                ? 'Keine Ergebnisse gefunden. Falls das öfter passiert, könnte ein Store gerade '
                      'nicht erreichbar sein (Store-Filter oben prüfen).'
                : 'Alle Treffer sind durch die aktiven Filter ausgeblendet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 3 / 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) => _StoreResultCard(result: visible[index]),
    );
  }
}

class _StoreResultCard extends StatelessWidget {
  const _StoreResultCard({required this.result});

  final _StoreResult result;

  static final _radius = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: _radius,
      child: InkWell(
        borderRadius: _radius,
        onTap: () => launchUrl(
          Uri.parse(result.url),
          mode: LaunchMode.externalApplication,
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: (result.imageUrl == null || result.imageUrl!.isEmpty)
                        ? Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          )
                        : CachedNetworkImage(
                            imageUrl: result.imageUrl!,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          result.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (result.genres.isNotEmpty)
                          Text(
                            result.genres.take(2).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (result.price != null)
                          Row(
                            children: [
                              if (result.isOnSale) ...[
                                Text(
                                  result.originalPrice ?? '',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                result.price!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: result.isOnSale
                                          ? Colors.greenAccent
                                          : null,
                                      fontWeight: result.isOnSale
                                          ? FontWeight.bold
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: result.platform.color.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(result.platform.icon, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        result.platform.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (result.isDlc || result.isDemo)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (result.isDlc ? Colors.deepOrange : Colors.blueAccent)
                              .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.isDlc ? 'DLC' : 'DEMO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (result.isOwned)
                Positioned(
                  right: 6,
                  bottom: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'In Bibliothek',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
