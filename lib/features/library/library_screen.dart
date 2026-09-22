import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../core/models/game_platform.dart';
import '../../core/models/library_game.dart';
import '../../core/steam/steam_app_details.dart';
import '../../core/steam/steam_game.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../../core/widgets/hover_lift.dart';
import '../auth/auth_state.dart';
import '../epic/epic_state.dart';
import '../itchio/itchio_state.dart';
import '../shell/app_shell.dart';
import '../sync/sync_state.dart';
import '../updates/updates_state.dart';
import '../wishlist/wishlist_state.dart';
import '../xbox/xbox_state.dart';
import 'game_details_dispatch.dart';
import 'launch_game.dart';
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
  final _searchFocus = FocusNode();
  String _query = '';
  _SortMode _sortMode = _SortMode.playtimeDesc;
  bool _onlyPlayed = false;
  bool _onlyUnplayed = false;
  bool _onlyControllerSupport = false;
  bool _onlyGerman = false;
  final Set<GamePlatform> _selectedPlatforms = {...GamePlatform.values};

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
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthState>();
    final library = context.read<LibraryState>();
    final itchio = context.read<ItchioState>();
    final epic = context.read<EpicState>();
    final wishlist = context.read<WishlistState>();
    final sync = context.read<SyncState>();
    final xbox = context.read<XboxState>();

    // Epic first — its own scan has to finish before sync() runs, since
    // sync() decides whether to push or pull the Epic snapshot based on
    // whether this device found anything locally (see SyncState.sync).
    // Same for Xbox/Microsoft Store.
    await Future.wait([epic.refresh(), xbox.refresh()]);
    if (!mounted) return;

    if (sync.status == SyncStatus.loggedIn) {
      await sync.sync(
        auth: auth,
        itchio: itchio,
        wishlist: wishlist,
        epic: epic,
        xbox: xbox,
      );
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
    library.setEpicGames(
      epic.games.isNotEmpty ? epic.games : sync.syncedEpicGames,
    );
    library.setXboxGames(
      xbox.games.isNotEmpty ? xbox.games : sync.syncedXboxGames,
    );
    unawaited(context.read<UpdatesState>().checkForUpdates(library.steamGames));
    unawaited(library.prefetchAppDetails());
    unawaited(library.prefetchEpicDetails());
    unawaited(
      wishlist.removeOwned(library.steamGames.map((g) => g.appId).toSet()),
    );
    // Import first, then refresh prices — importing can upgrade Steam-only
    // placeholder entries to real ITAD ids, which refreshPrices needs to see
    // to fetch their prices. Running them concurrently raced the two.
    unawaited(() async {
      if (auth.accounts.isNotEmpty) {
        await wishlist.importFromSteam(auth.accounts);
      }
      await wishlist.refreshPrices();
    }());
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

  /// Search, filters or a non-default sort hide the hero and the
  /// "Weiter spielen"/alert rows, so results start right at the top.
  bool get _isFiltering => _query.isNotEmpty || _activeFilterCount > 0;

  void _togglePlatformOnly(GamePlatform platform) {
    setState(() {
      final onlyThis =
          _selectedPlatforms.length == 1 &&
          _selectedPlatforms.contains(platform);
      _selectedPlatforms.clear();
      if (onlyThis) {
        _selectedPlatforms.addAll(GamePlatform.values);
      } else {
        _selectedPlatforms.add(platform);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final wishlist = context.watch<WishlistState>();
    final filtered = _applyFiltersAndSort(
      library.games,
      library.appDetailsCache,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              _buildHeader(library),
              Expanded(child: _buildBody(library, filtered, wishlist)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LibraryState library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bibliothek',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Bricolage Grotesque',
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                library.isPrefetchingDetails
                    ? 'Lade Zusatzinfos… ${library.prefetchedCount}/${library.games.length}'
                    : '${library.games.length} Spiele',
                style: zerMonoTextStyle.copyWith(
                  color: zerTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 340,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Spiele durchsuchen…',
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        tooltip: 'Suche leeren',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      )
                    : const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _KeyHint('Ctrl K'),
                      ),
                suffixIconConstraints: const BoxConstraints(minHeight: 0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Aktualisieren (F5)',
            onPressed: library.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(backgroundColor: zerSurfaceHigh),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsRow(LibraryState library) {
    final allSelected = _selectedPlatforms.length == GamePlatform.values.length;
    final present = {for (final g in library.games) g.platform};
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _PillChip(
            label: 'Alle',
            trailing: '${library.games.length}',
            selected: allSelected,
            onTap: () => setState(() {
              _selectedPlatforms
                ..clear()
                ..addAll(GamePlatform.values);
            }),
          ),
          for (final platform in GamePlatform.values)
            if (present.contains(platform))
              _PillChip(
                label: platform.label,
                leading: platform,
                selected: !allSelected && _selectedPlatforms.contains(platform),
                onTap: () => _togglePlatformOnly(platform),
              ),
          _PillChip(
            label: 'Backlog',
            icon: Icons.inventory_2_outlined,
            selected: _onlyUnplayed,
            onTap: () => setState(() {
              _onlyUnplayed = !_onlyUnplayed;
              if (_onlyUnplayed) _onlyPlayed = false;
            }),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<_SortMode>(
            tooltip: 'Sortierung',
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (_) => [
              for (final mode in _SortMode.values)
                PopupMenuItem(value: mode, child: Text(mode.label)),
            ],
            child: _PillChip(
              label: _sortMode.label,
              icon: Icons.swap_vert,
              selected: false,
            ),
          ),
          _PillChip(
            label: _activeFilterCount > 0
                ? 'Filter · $_activeFilterCount'
                : 'Filter',
            icon: Icons.tune,
            selected: _onlyControllerSupport || _onlyGerman || _onlyPlayed,
            onTap: _openFilterSheet,
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
                              avatar: PlatformLogo(
                                platform,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
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
                            avatar: const Icon(
                              Icons.gamepad_outlined,
                              size: 16,
                            ),
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

  Widget _buildBody(
    LibraryState library,
    List<LibraryGame> filtered,
    WishlistState wishlist,
  ) {
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

    final recent = library.games.where((g) => g.lastPlayed != null).toList()
      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    final showExtras = !_isFiltering;
    final alerts = wishlist.alertedEntries;

    const hPad = EdgeInsets.symmetric(horizontal: 28);

    return CustomScrollView(
      slivers: [
        if (showExtras && recent.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
            sliver: SliverToBoxAdapter(child: _HeroBanner(game: recent.first)),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
          sliver: SliverToBoxAdapter(child: _buildChipsRow(library)),
        ),
        if (showExtras && recent.length > 1) ...[
          const SliverPadding(
            padding: hPad,
            sliver: SliverToBoxAdapter(child: _SectionTitle('Weiter spielen')),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 246,
              child: ListView.separated(
                padding: hPad.copyWith(top: 4, bottom: 8),
                scrollDirection: Axis.horizontal,
                itemCount: recent.length.clamp(0, 12) - 1,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) => SizedBox(
                  width: 156,
                  child: _GameCard(game: recent[index + 1]),
                ),
              ),
            ),
          ),
        ],
        if (showExtras && alerts.isNotEmpty) ...[
          SliverPadding(
            padding: hPad,
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                'Preisalarme auf deiner Wunschliste',
                trailing: '${alerts.length}',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                padding: hPad.copyWith(top: 4, bottom: 8),
                scrollDirection: Axis.horizontal,
                itemCount: alerts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _DealTile(
                  entry: alerts[index],
                  onTap: () => AppShell.select(context, AppSection.wishlist),
                ),
              ),
            ),
          ),
        ],
        SliverPadding(
          padding: hPad,
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(
              _isFiltering ? 'Ergebnisse' : 'Alle Spiele',
              trailing: '${filtered.length}',
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: Text('Keine Spiele gefunden.')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 18,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _GameCard(game: filtered[index]),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

String _relativeDay(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final days = today.difference(DateUtils.dateOnly(date)).inDays;
  if (days <= 0) return 'heute';
  if (days == 1) return 'gestern';
  if (days < 30) return 'vor $days Tagen';
  return 'am ${date.day}.${date.month}.${date.year}';
}

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: zerDivider),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: zerMonoTextStyle.copyWith(fontSize: 11, color: zerTextSecondary),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.leading,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final GamePlatform? leading;
  final IconData? icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? zerBackground : zerTextPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? zerTextPrimary : zerSurfaceHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  PlatformLogo(leading!, size: 14, color: fg),
                  const SizedBox(width: 7),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    trailing!,
                    style: zerMonoTextStyle.copyWith(
                      color: fg.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: zerMonoTextStyle.copyWith(
                color: zerTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Big "continue where you left off" banner for the most recently played
/// game — wide key art, dimmed towards the text side.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    final game = this.game;
    final heroUrl = game is SteamGame
        ? game.libraryHeroUrl
        : game.headerImageUrl;
    final radius = BorderRadius.circular(20);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (heroUrl.isEmpty)
              _NoCoverPlaceholder(game: game)
            else
              CachedNetworkImage(
                imageUrl: heroUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorWidget: (_, _, _) => game.headerImageUrl.isEmpty
                    ? _NoCoverPlaceholder(game: game)
                    : CachedNetworkImage(
                        imageUrl: game.headerImageUrl,
                        fit: BoxFit.cover,
                      ),
                placeholder: (_, _) => Container(color: zerSurfaceHigh),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: zerCardBorder),
              ),
            ),
            Positioned(
              left: 32,
              bottom: 28,
              right: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PlatformBadge(platform: game.platform),
                      const SizedBox(width: 10),
                      Text(
                        'Zuletzt gespielt ${_relativeDay(game.lastPlayed!)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => launchLibraryGame(context, game),
                        style: FilledButton.styleFrom(
                          backgroundColor: zerAccent,
                          foregroundColor: zerOnAccent,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'Spielen',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => pushGameDetails(context, game),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Details'),
                      ),
                      const SizedBox(width: 18),
                      if (game.hasPlaytimeData && game.hasBeenPlayed)
                        Text(
                          '${game.playtimeForeverHours.toStringAsFixed(1)} h gespielt',
                          style: zerMonoTextStyle.copyWith(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealTile extends StatelessWidget {
  const _DealTile({required this.entry, required this.onTap});

  final WishlistEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final appId = entry.steamAppId;
    return SizedBox(
      width: 240,
      child: HoverLift(
        borderRadius: radius,
        child: Material(
          color: zerSurfaceHigh,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (appId != null)
                  CachedNetworkImage(
                    imageUrl:
                        'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg',
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.local_offer_rounded,
                        size: 14,
                        color: Color(0xFF7EE2A8),
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

/// Portrait library card: box art, store badge, name, and a play button
/// that fades in on hover.
class _GameCard extends StatefulWidget {
  const _GameCard({required this.game});

  final LibraryGame game;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _hovering = false;

  static final _radius = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: HoverLift(
        borderRadius: _radius,
        child: Material(
          color: zerSurfaceHigh,
          borderRadius: _radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => pushGameDetails(context, game),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CoverImage(game: game),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 28, 10, 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.15,
                          ),
                        ),
                        if (game.hasPlaytimeData && game.hasBeenPlayed)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${game.playtimeForeverHours.toStringAsFixed(1)} h',
                              style: zerMonoTextStyle.copyWith(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _PlatformBadge(platform: game.platform, compact: true),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: AnimatedOpacity(
                    opacity: _hovering ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: IgnorePointer(
                      ignoring: !_hovering,
                      child: Material(
                        color: zerAccent,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: game.primaryActionLabel,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            game.platform == GamePlatform.itchio
                                ? Icons.open_in_new
                                : Icons.play_arrow_rounded,
                            color: zerOnAccent,
                          ),
                          onPressed: () => launchLibraryGame(context, game),
                        ),
                      ),
                    ),
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

/// Portrait art when the store has it; otherwise the landscape header is
/// shown centred over a blurred, stretched copy of itself so every card
/// keeps the same 2:3 shape.
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(color: zerSurfaceHigh);

    if (game.coverIsPortrait) {
      return CachedNetworkImage(
        imageUrl: game.coverImageUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder(),
        errorWidget: (_, _, _) => _LandscapeCover(game: game),
      );
    }
    return _LandscapeCover(game: game);
  }
}

class _LandscapeCover extends StatelessWidget {
  const _LandscapeCover({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    final url = game.headerImageUrl;
    if (url.isEmpty) return _NoCoverPlaceholder(game: game);

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _NoCoverPlaceholder(game: game),
          ),
        ),
        Container(color: Colors.black26),
        Align(
          alignment: const Alignment(0, -0.35),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.fitWidth,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// Shown instead of the cover image when a store exposes no artwork — a
/// branded gradient with the store logo beats a broken-image icon.
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
      child: PlatformLogo(game.platform, size: 44, color: Colors.white24),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.platform, this.compact = false});

  final GamePlatform platform;

  /// Logo only — used on the small grid cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: platform.label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlatformLogo(platform, size: 13),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                platform.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
