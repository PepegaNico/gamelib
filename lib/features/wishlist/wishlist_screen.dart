import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/itad/itad_models.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../auth/auth_state.dart';
import '../settings/settings_screen.dart';
import 'wishlist_state.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

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
          Expanded(child: _WishlistList(wishlist: wishlist)),
        ],
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
  const _WishlistList({required this.wishlist});

  final WishlistState wishlist;

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

  @override
  Widget build(BuildContext context) {
    if (wishlist.entries.isEmpty) {
      return const Center(child: Text('Deine Wishlist ist leer.'));
    }

    final alerted = wishlist.alertedEntries.map((e) => e.itadGameId).toSet();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: wishlist.entries.length,
      itemBuilder: (context, index) {
        final entry = wishlist.entries[index];
        final price = wishlist.priceCache[entry.itadGameId];
        final isAlerted = alerted.contains(entry.itadGameId);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: isAlerted
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
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
                            onPressed: () => _editTargetPrice(context, entry),
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
                      _DealsComparison(
                        price: price,
                        isLoading: wishlist.isLoading,
                      ),
                    ],
                  ),
                ),
              ],
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

/// Lists the cheapest few shops for a wishlist entry so the whole point of
/// tracking it — where it's cheapest right now, across stores — is visible
/// at a glance instead of just a single "best price" line.
class _DealsComparison extends StatelessWidget {
  const _DealsComparison({required this.price, required this.isLoading});

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
    if (info.deals.isEmpty) {
      return Text(
        'Kein Angebot gefunden',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final deal in info.deals.take(3))
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(deal.url),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      deal.shopName,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (deal.cutPercent > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${deal.cutPercent}%',
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
                    deal.price.formatted,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (info.historyLowAll != null)
          Text(
            'Tiefstpreis: ${info.historyLowAll!.formatted}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    );
  }
}
