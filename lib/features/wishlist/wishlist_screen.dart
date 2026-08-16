import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/itad/itad_models.dart';
import '../../core/wishlist/wishlist_entry.dart';
import '../settings/settings_screen.dart';
import 'wishlist_state.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist & Preisalarm'),
        actions: [
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
      body: !wishlist.isConnected
          ? _NotConnected()
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: _AddGameField(),
                ),
                Expanded(child: _WishlistList(wishlist: wishlist)),
              ],
            ),
    );
  }
}

class _NotConnected extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.price_check, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Verbinde zuerst IsThereAnyDeal in den Einstellungen, um Preise zu verfolgen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: const Text('Zu den Einstellungen'),
            ),
          ],
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
      itemCount: wishlist.entries.length,
      itemBuilder: (context, index) {
        final entry = wishlist.entries[index];
        final price = wishlist.priceCache[entry.itadGameId];
        final isAlerted = alerted.contains(entry.itadGameId);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isAlerted
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            title: Text(entry.title),
            subtitle: _PriceSubtitle(
              price: price,
              isLoading: wishlist.isLoading,
            ),
            leading: isAlerted
                ? const Icon(Icons.notifications_active, color: Colors.orange)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.targetPriceAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      label: Text(
                        'Ziel: ${entry.targetPriceAmount!.toStringAsFixed(2)} €',
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Preisalarm setzen',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _editTargetPrice(context, entry),
                ),
                IconButton(
                  tooltip: 'Entfernen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      context.read<WishlistState>().remove(entry.itadGameId),
                ),
              ],
            ),
            onTap: price?.bestDeal != null
                ? () => launchUrl(
                    Uri.parse(price!.bestDeal!.url),
                    mode: LaunchMode.externalApplication,
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _PriceSubtitle extends StatelessWidget {
  const _PriceSubtitle({required this.price, required this.isLoading});

  final ItadPriceInfo? price;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final currentPrice = price;
    if (currentPrice == null) {
      return Text(isLoading ? 'Lade Preis…' : 'Kein Preis gefunden');
    }
    final best = currentPrice.bestDeal;
    final low = currentPrice.historyLowAll;
    final parts = <String>[
      if (best != null) 'Ab ${best.price.formatted} bei ${best.shopName}',
      if (low != null) 'Tiefstpreis: ${low.formatted}',
    ];
    return Text(parts.isEmpty ? 'Kein Angebot gefunden' : parts.join(' · '));
  }
}
