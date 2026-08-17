import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import '../../core/models/game_platform.dart';
import '../../core/models/library_game.dart';
import '../../core/steam/steam_app_details.dart';
import '../../core/steam/steam_game.dart';
import '../../core/widgets/hover_lift.dart';
import '../auth/auth_state.dart';
import '../epic/epic_launch.dart';
import '../epic/epic_state.dart';
import '../itchio/itchio_state.dart';
import '../settings/settings_screen.dart';
import '../store/store_search_screen.dart';
import '../sync/sync_state.dart';
import '../updates/updates_screen.dart';
import '../updates/updates_state.dart';
import '../wishlist/wishlist_screen.dart';
import '../wishlist/wishlist_state.dart';
import 'backlog_picker.dart';
import 'game_details_dispatch.dart';
import 'library_state.dart';

enum _SortMode { playtimeDesc, nameAsc, lastPlayedDesc }

extension on _SortMode {
  String get label => switch (this) {
    _SortMode.playtimeDesc => 'Meistgespielt',
    _SortMode.nameAsc => 'Name (A-Z)',
    _SortMode.lastPlayedDesc => 'Zuletzt gespielt',
  };
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _SortMode _sortMode = _SortMode.playtimeDesc;
  bool _onlyPlayed = false;
  bool _onlyUnplayed = false;
  bool _onlyControllerSupport = false;
  bool _onlyGerman = false;
  final Set<GamePlatform> _selectedPlatforms = {...GamePlatform.values};
  int _railIndex = 0;

  /// Null until the user explicitly toggles it, so the sidebar defaults to
  /// expanded on wide (desktop) windows and collapsed on narrow (phone) ones.
  bool? _menuExpanded;

  int get _activeFilterCount {
    var count = 0;
    if (_selectedPlatforms.length != GamePlatform.values.length) count++;
    if (_onlyPlayed) count++;
    if (_onlyUnplayed) count++;
    if (_onlyControllerSupport) count++;
    if (_onlyGerman) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthState>();
    final library = context.read<LibraryState>();
    final itchio = context.read<ItchioState>();
    final epic = context.read<EpicState>();
    final wishlist = context.read<WishlistState>();
    final sync = context.read<SyncState>();

    // Epic first — its own scan has to finish before sync() runs, since
    // sync() decides whether to push or pull the Epic snapshot based on
    // whether this device found anything locally (see SyncState.sync).
    await epic.refresh();
    if (!mounted) return;

    if (sync.status == SyncStatus.loggedIn) {
      await sync.sync(auth: auth, itchio: itchio, wishlist: wishlist, epic: epic);
      if (!mounted) return;
    }

    final futures = <Future<void>>[];
    if (auth.accounts.isNotEmpty) {
      futures.add(library.load(accounts: auth.accounts));
    }
    if (itchio.isConnected) {
      futures.add(itchio.refresh());
    }
    await Future.wait(futures);
    if (!mounted) return;

    library.setItchioGames(itchio.games);
    library.setEpicGames(epic.games.isNotEmpty ? epic.games : sync.syncedEpicGames);
    unawaited(context.read<UpdatesState>().checkForUpdates(library.steamGames));
    unawaited(library.prefetchAppDetails());
    unawaited(library.prefetchEpicDetails());
    unawaited(wishlist.refreshPrices());
  }

  List<LibraryGame> _applyFiltersAndSort(
    List<LibraryGame> games,
    Map<int, SteamAppDetails> appDetailsCache,
  ) {
    var result = games.where((g) => _selectedPlatforms.contains(g.platform));

    if (_query.isNotEmpty) {
      result = result.where(
        (g) => g.name.toLowerCase().contains(_query.toLowerCase()),
      );
    }
    if (_onlyPlayed) {
      result = result.where((g) => g.hasPlaytimeData && g.hasBeenPlayed);
    }
    if (_onlyUnplayed) {
      result = result.where((g) => !g.hasPlaytimeData || !g.hasBeenPlayed);
    }
    if (_onlyControllerSupport) {
      result = result.where(
        (g) =>
            g is SteamGame &&
            (appDetailsCache[g.appId]?.fullControllerSupport ?? false),
      );
    }
    if (_onlyGerman) {
      result = result.where(
        (g) =>
            g is SteamGame &&
            (appDetailsCache[g.appId]?.supportsGerman ?? false),
      );
    }

    final list = result.toList();
    switch (_sortMode) {
      case _SortMode.playtimeDesc:
        list.sort(
          (a, b) => b.playtimeForeverHours.compareTo(a.playtimeForeverHours),
        );
      case _SortMode.nameAsc:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortMode.lastPlayedDesc:
        list.sort((a, b) {
          final aTime = a.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
    }
    return list;
  }

  void _navigateTo(int index, Widget screen) {
    setState(() => _railIndex = index);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
          if (mounted) setState(() => _railIndex = 0);
        });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final library = context.watch<LibraryState>();
    final wishlistAlerts = context.watch<WishlistState>().alertedEntries.length;
    final updatesUnread = context.watch<UpdatesState>().unreadCount;
    final filtered = _applyFiltersAndSort(
      library.games,
      library.appDetailsCache,
    );
    final menuExpanded =
        _menuExpanded ?? MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: menuExpanded ? 'Menü einklappen' : 'Menü ausklappen',
          icon: Icon(menuExpanded ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _menuExpanded = !menuExpanded),
        ),
        title: Row(
          children: [
            if (auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty) ...[
              CircleAvatar(
                backgroundImage: NetworkImage(auth.avatarUrl!),
                radius: 14,
              ),
              const SizedBox(width: 10),
            ],
            Text(auth.personaName ?? 'Meine Bibliothek'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: library.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Abmelden',
            onPressed: () => context.read<AuthState>().signOut(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (menuExpanded) ...[
          NavigationRail(
            selectedIndex: _railIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  setState(() => _railIndex = 0);
                case 1:
                  _navigateTo(1, const StoreSearchScreen());
                case 2:
                  _navigateTo(2, const WishlistScreen());
                case 3:
                  _navigateTo(3, const UpdatesScreen());
              }
            },
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.videogame_asset_outlined),
                selectedIcon: Icon(Icons.videogame_asset),
                label: Text('Bibliothek'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: Text('Store'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: wishlistAlerts > 0,
                  label: Text('$wishlistAlerts'),
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.favorite_border),
                ),
                selectedIcon: const Icon(Icons.favorite),
                label: const Text('Wishlist'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: updatesUnread > 0,
                  label: Text('$updatesUnread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: const Icon(Icons.notifications),
                label: const Text('Updates'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                _buildSearchAndFilterBar(library),
                if (!library.isLoading && library.games.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtered.length} von ${library.games.length} Spielen',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                Expanded(child: _buildBody(library, filtered)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: library.games.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showBacklogPicker(context, library.games),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Was soll ich spielen?'),
            ),
    );
  }

  /// Compact search + filter bar. The actual filter controls live behind
  /// the funnel button in a bottom sheet (see [_openFilterSheet]) instead of
  /// always taking up vertical space above the grid.
  Widget _buildSearchAndFilterBar(LibraryState library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (library.isPrefetchingDetails)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lade Zusatzinfos… ${library.prefetchedCount}/${library.games.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Spiele durchsuchen…',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _activeFilterCount > 0,
                label: Text('$_activeFilterCount'),
                child: IconButton(
                  tooltip: 'Filter & Sortierung',
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void update(VoidCallback change) {
              setState(change);
              setSheetState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter & Sortierung',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_activeFilterCount > 0)
                            TextButton(
                              onPressed: () => update(() {
                                _selectedPlatforms
                                  ..clear()
                                  ..addAll(GamePlatform.values);
                                _onlyPlayed = false;
                                _onlyUnplayed = false;
                                _onlyControllerSupport = false;
                                _onlyGerman = false;
                              }),
                              child: const Text('Zurücksetzen'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Plattform',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final platform in GamePlatform.values)
                            FilterChip(
                              avatar: Icon(platform.icon, size: 16),
                              label: Text(platform.label),
                              selected: _selectedPlatforms.contains(platform),
                              onSelected: (selected) => update(() {
                                if (selected) {
                                  _selectedPlatforms.add(platform);
                                } else {
                                  _selectedPlatforms.remove(platform);
                                }
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            avatar: const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: const Text('Nur gespielte'),
                            selected: _onlyPlayed,
                            onSelected: (selected) => update(() {
                              _onlyPlayed = selected;
                              if (selected) _onlyUnplayed = false;
                            }),
                          ),
                          FilterChip(
                            avatar: const Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                            ),
                            label: const Text('Nur ungespielt (Backlog)'),
                            selected: _onlyUnplayed,
                            onSelected: (selected) => update(() {
                              _onlyUnplayed = selected;
                              if (selected) _onlyPlayed = false;
                            }),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.gamepad_outlined, size: 16),
                            label: const Text('Controller-Support'),
                            selected: _onlyControllerSupport,
                            onSelected: (selected) =>
                                update(() => _onlyControllerSupport = selected),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.translate, size: 16),
                            label: const Text('Deutsch verfügbar'),
                            selected: _onlyGerman,
                            onSelected: (selected) =>
                                update(() => _onlyGerman = selected),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sortierung',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      for (final mode in _SortMode.values)
                        RadioListTile<_SortMode>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(mode.label),
                          value: mode,
                          groupValue: _sortMode,
                          onChanged: (value) =>
                              update(() => _sortMode = value!),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(LibraryState library, List<LibraryGame> filtered) {
    if (library.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (library.errorMessage != null && library.games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(library.errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (filtered.isEmpty) {
      return const Center(child: Text('Keine Spiele gefunden.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 460 / 215,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _GameCard(game: filtered[index]),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final LibraryGame game;

  Future<void> _launchPrimaryAction(BuildContext context) async {
    if (game is EpicGame) {
      await launchEpicGame(context, game as EpicGame);
      return;
    }

    final launched = await launchUrl(Uri.parse(game.primaryActionUrl));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${game.primaryActionLabel} fehlgeschlagen.')),
      );
    }
  }

  static final _radius = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: _radius,
      child: InkWell(
        borderRadius: _radius,
        onTap: () => pushGameDetails(context, game),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (game.headerImageUrl.isEmpty)
                _NoCoverPlaceholder(game: game)
              else
                CachedNetworkImage(
                  imageUrl: game.headerImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      _NoCoverPlaceholder(game: game),
                  placeholder: (context, url) => Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
              Positioned(
                left: 8,
                top: 8,
                child: _PlatformBadge(platform: game.platform),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: game.primaryActionLabel,
                    icon: Icon(
                      game.platform == GamePlatform.itchio
                          ? Icons.open_in_new
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () => _launchPrimaryAction(context),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        game.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (game.hasPlaytimeData)
                        Text(
                          '${game.playtimeForeverHours.toStringAsFixed(1)} h gespielt',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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

/// Shown instead of the cover image for platforms whose API doesn't expose
/// artwork (currently Epic) — a branded gradient beats a broken-image icon.
class _NoCoverPlaceholder extends StatelessWidget {
  const _NoCoverPlaceholder({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            game.platform.color,
            Color.lerp(game.platform.color, Colors.black, 0.5)!,
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Icon(game.platform.icon, size: 40, color: Colors.white24),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.platform});

  final GamePlatform platform;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: platform.color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(platform.icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            platform.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
