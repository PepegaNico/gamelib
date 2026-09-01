import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/itad/itad_models.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../auth/auth_state.dart';
import '../settings/settings_screen.dart';
import 'wishlist_state.dart';

enum _SortMode {
  standard('Hinzugefügt', Icons.sort),
  discountDesc('Höchster Rabatt', Icons.local_offer_outlined),
  priceAsc('Günstigster Preis', Icons.trending_down),
  targetReached('Zielpreis erreicht', Icons.notifications_active_outlined);

  const _SortMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  _SortMode _sortMode = _SortMode.standard;
  bool _onlyOnSale = false;

  Future<void> _importFromSteam(BuildContext context) async {
    final auth = context.read<AuthState>();
    final wishlist = context.read<WishlistState>();
    if (auth.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erst ein Steam-Konto in den Einstellungen verbinden.'),
        ),
      );
      return;
    }

    final error = await wishlist.importFromSteam(auth.accounts);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Steam-Wishlist importiert.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist & Preisalarm'),
        actions: [
          PopupMenuButton<_SortMode>(
            tooltip: 'Sortieren',
            icon: const Icon(Icons.sort),
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              for (final mode in _SortMode.values)
                PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(mode.icon, size: 18),
                      const SizedBox(width: 10),
                      Text(mode.label),
                      if (mode == _sortMode) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 18),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Steam-Wishlist importieren',
            onPressed: wishlist.isLoading
                ? null
                : () => _importFromSteam(context),
            icon: const Icon(Icons.download_outlined),
          ),
          if (wishlist.isConnected)
            IconButton(
              tooltip: 'Preise aktualisieren',
              onPressed: wishlist.isLoading
                  ? null
                  : () => wishlist.refreshPrices(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          if (wishlist.isConnected)
            const Padding(
              padding: EdgeInsets.all(16),
              child: _AddGameField(),
            )
          else
            _NoItadHint(),
          if (wishlist.isLoading && wishlist.steamImportTotal > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: wishlist.steamImportDone / wishlist.steamImportTotal,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Importiere Steam-Wishlist… '
                    '${wishlist.steamImportDone}/${wishlist.steamImportTotal}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          _OnSaleSummary(
            wishlist: wishlist,
            active: _onlyOnSale,
            onTap: () => setState(() => _onlyOnSale = !_onlyOnSale),
          ),
          Expanded(
            child: _WishlistList(
              wishlist: wishlist,
              sortMode: _sortMode,
              onlyOnSale: _onlyOnSale,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed at-a-glance count of wishlist games currently on sale —
/// otherwise you'd have to open every card to find out. Doubles as the
/// toggle for the "nur im Angebot" filter so acting on it is one tap.
class _OnSaleSummary extends StatelessWidget {
  const _OnSaleSummary({
    required this.wishlist,
    required this.active,
    required this.onTap,
  });

  final WishlistState wishlist;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSaleCount = wishlist.entries.where((e) {
      final best = wishlist.priceCache[e.itadGameId]?.bestDeal;
      return best != null && best.cutPercent > 0;
    }).length;

    if (onSaleCount == 0 && !active) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: active ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onSaleCount == 0 && !active ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer,
                  size: 18,
                  color: active ? colorScheme.onPrimaryContainer : colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    onSaleCount == 0
                        ? 'Aktuell keine Wishlist-Spiele im Angebot'
                        : '$onSaleCount Spiel${onSaleCount == 1 ? '' : 'e'} deiner Wishlist '
                              'gerade im Angebot',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: active ? colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                ),
                if (active)
                  Icon(
                    Icons.filter_alt,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the ITAD search-add field when IsThereAnyDeal isn't
/// connected — the Steam-Wishlist import (AppBar button) works without it,
/// this is purely about the extras ITAD adds (cross-store price comparison,
/// manual add-by-search).
class _NoItadHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ohne IsThereAnyDeal siehst du hier nur die Spielnamen ohne '
                  'Preisvergleich. Verbinde es in den Einstellungen für '
                  'Preise über alle Stores hinweg und manuelles Hinzufügen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                child: const Text('Einstellungen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddGameField extends StatefulWidget {
  const _AddGameField();

  @override
  State<_AddGameField> createState() => _AddGameFieldState();
}

class _AddGameFieldState extends State<_AddGameField> {
  final _controller = TextEditingController();
  List<ItadGameMatch> _results = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await context.read<WishlistState>().search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onSubmitted: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Spiel zur Wishlist hinzufügen…',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _search(_controller.text),
            ),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final match = _results[index];
                return ListTile(
                  dense: true,
                  title: Text(match.title),
                  trailing: const Icon(Icons.add),
                  onTap: () async {
                    await context.read<WishlistState>().add(match);
                    _controller.clear();
                    setState(() => _results = []);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${match.title} zur Wishlist hinzugefügt.',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _WishlistList extends StatelessWidget {
  const _WishlistList({
    required this.wishlist,
    required this.sortMode,
    required this.onlyOnSale,
  });

  final WishlistState wishlist;
  final _SortMode sortMode;
  final bool onlyOnSale;

  List<WishlistEntry> _visibleEntries() {
    var list = wishlist.entries;
    if (onlyOnSale) {
      list = list.where((e) {
        final best = wishlist.priceCache[e.itadGameId]?.bestDeal;
        return best != null && best.cutPercent > 0;
      }).toList();
    }

    switch (sortMode) {
      case _SortMode.standard:
        return list;
      case _SortMode.discountDesc:
        list = [...list]
          ..sort((a, b) {
            final cutA = wishlist.priceCache[a.itadGameId]?.bestDeal?.cutPercent ?? -1;
            final cutB = wishlist.priceCache[b.itadGameId]?.bestDeal?.cutPercent ?? -1;
            return cutB.compareTo(cutA);
          });
        return list;
      case _SortMode.priceAsc:
        list = [...list]
          ..sort((a, b) {
            final priceA =
                wishlist.priceCache[a.itadGameId]?.bestDeal?.price.amount ??
                double.infinity;
            final priceB =
                wishlist.priceCache[b.itadGameId]?.bestDeal?.price.amount ??
                double.infinity;
            return priceA.compareTo(priceB);
          });
        return list;
      case _SortMode.targetReached:
        final alerted = wishlist.alertedEntries
            .map((e) => e.itadGameId)
            .toSet();
        list = [...list]
          ..sort((a, b) {
            final aAlerted = alerted.contains(a.itadGameId) ? 0 : 1;
            final bAlerted = alerted.contains(b.itadGameId) ? 0 : 1;
            return aAlerted.compareTo(bAlerted);
          });
        return list;
    }
  }

  Future<void> _editTargetPrice(
    BuildContext context,
    WishlistEntry entry,
  ) async {
    final controller = TextEditingController(
      text: entry.targetPriceAmount?.toStringAsFixed(2) ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preisalarm für ${entry.title}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Zielpreis (leer lassen zum Entfernen)',
            prefixText: '€ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result == null || !context.mounted) return;
    final amount = double.tryParse(result.replaceAll(',', '.'));
    await context.read<WishlistState>().setTargetPrice(
      entry.itadGameId,
      amount,
    );
  }

  void _openDealsSheet(
    BuildContext context,
    WishlistEntry entry,
    ItadPriceInfo? price,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DealsSheet(entry: entry, price: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (wishlist.entries.isEmpty) {
      return const Center(child: Text('Deine Wishlist ist leer.'));
    }

    final visible = _visibleEntries();
    if (visible.isEmpty) {
      return const Center(
        child: Text('Keine Wishlist-Spiele passen zum aktuellen Filter.'),
      );
    }

    final alerted = wishlist.alertedEntries.map((e) => e.itadGameId).toSet();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final entry = visible[index];
        final price = wishlist.priceCache[entry.itadGameId];
        final isAlerted = alerted.contains(entry.itadGameId);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: isAlerted
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openDealsSheet(context, entry, price),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 110,
                      height: 52,
                      child: entry.steamAppId != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  'https://cdn.akamai.steamstatic.com/steam/apps/'
                                  '${entry.steamAppId}/header.jpg',
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const _CoverPlaceholder(),
                              placeholder: (context, url) => Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            )
                          : const _CoverPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isAlerted)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.notifications_active,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Preisalarm setzen',
                              icon: const Icon(
                                Icons.notifications_outlined,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _editTargetPrice(context, entry),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Entfernen',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => context
                                  .read<WishlistState>()
                                  .remove(entry.itadGameId),
                            ),
                          ],
                        ),
                        if (entry.targetPriceAmount != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                'Ziel: ${entry.targetPriceAmount!.toStringAsFixed(2)} €',
                              ),
                            ),
                          ),
                        _BestPriceSummary(
                          price: price,
                          isLoading: wishlist.isLoading,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.videogame_asset_outlined,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

/// Shows just the single cheapest current offer on the wishlist card itself
/// — tap the card to see every shop (see _DealsSheet). Keeping the card to
/// one line avoids the previous top-3 list clashing with the all-time-low,
/// which was often a different, no-longer-available price and read as
/// "wrong" next to the current offers.
class _BestPriceSummary extends StatelessWidget {
  const _BestPriceSummary({required this.price, required this.isLoading});

  final ItadPriceInfo? price;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final info = price;
    if (info == null) {
      return Text(
        isLoading ? 'Lade Preise…' : 'Kein Preis gefunden',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final best = info.bestDeal;
    if (best == null) {
      return Text(
        'Kein Angebot gefunden',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            best.shopName,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (best.cutPercent > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '-${best.cutPercent}%',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          best.price.formatted,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (info.deals.length > 1) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
        ],
      ],
    );
  }
}

/// Full price comparison for one wishlist entry, opened by tapping its
/// card — lists every offer ITAD found (not just the cheapest few), each
/// tappable to open the shop. The all-time low is shown separately and
/// clearly labeled, since it's a historical price that may no longer be
/// available and previously got confused with the current offers.
class _DealsSheet extends StatelessWidget {
  const _DealsSheet({required this.entry, required this.price});

  final WishlistEntry entry;
  final ItadPriceInfo? price;

  @override
  Widget build(BuildContext context) {
    final info = price;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                entry.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (info?.historyLowAll != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tiefster Preis aller Zeiten: '
                  '${info!.historyLowAll!.formatted} '
                  '(evtl. aktuell nicht mehr verfügbar)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: (info == null || info.deals.isEmpty)
                    ? Center(
                        child: Text(
                          info == null
                              ? 'Kein Preis gefunden'
                              : 'Kein Angebot gefunden',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: info.deals.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final deal = info.deals[index];
                          return ListTile(
                            title: Text(deal.shopName),
                            subtitle: deal.cutPercent > 0
                                ? Text(
                                    '-${deal.cutPercent}% · statt ${deal.regular.formatted}',
                                  )
                                : null,
                            trailing: Text(
                              deal.price.formatted,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => launchUrl(
                              Uri.parse(deal.url),
                              mode: LaunchMode.externalApplication,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
