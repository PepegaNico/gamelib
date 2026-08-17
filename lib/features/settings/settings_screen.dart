import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_state.dart';
import '../epic/epic_state.dart';
import '../itchio/itchio_state.dart';
import '../wishlist/wishlist_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _steamController = TextEditingController();
  final _steamFormKey = GlobalKey<FormState>();
  bool _savingSteam = false;

  final _addSteamController = TextEditingController();
  bool _addingSteamAccount = false;
  String? _addSteamError;

  final _itchioController = TextEditingController();
  bool _connectingItchio = false;

  final _itadController = TextEditingController();
  bool _connectingItad = false;

  @override
  void dispose() {
    _steamController.dispose();
    _addSteamController.dispose();
    _itchioController.dispose();
    _itadController.dispose();
    super.dispose();
  }

  Future<void> _openSteamApiKeyPage() async {
    await launchUrl(
      Uri.parse('https://steamcommunity.com/dev/apikey'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openItchioApiKeyPage() async {
    await launchUrl(
      Uri.parse('https://itch.io/user/settings/api-keys'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openItadApiKeyPage() async {
    await launchUrl(
      Uri.parse('https://isthereanydeal.com/apps/my/'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _saveSteamKey() async {
    if (!_steamFormKey.currentState!.validate()) return;
    setState(() => _savingSteam = true);
    await context.read<AuthState>().saveApiKey(_steamController.text.trim());
    setState(() => _savingSteam = false);
  }

  Future<void> _addSteamAccount() async {
    final key = _addSteamController.text.trim();
    if (key.length != 32) {
      setState(() => _addSteamError = 'Ein gültiger Steam-API-Key hat 32 Zeichen.');
      return;
    }
    setState(() {
      _addingSteamAccount = true;
      _addSteamError = null;
    });
    final error = await context.read<AuthState>().addAccount(key);
    if (!mounted) return;
    setState(() {
      _addingSteamAccount = false;
      _addSteamError = error;
    });
    if (error == null) _addSteamController.clear();
  }

  Future<void> _connectItchio() async {
    final key = _itchioController.text.trim();
    if (key.isEmpty) return;
    setState(() => _connectingItchio = true);
    final error = await context.read<ItchioState>().addAccount(key);
    if (!mounted) return;
    setState(() => _connectingItchio = false);
    if (error == null) _itchioController.clear();
  }

  Future<void> _connectItad() async {
    final key = _itadController.text.trim();
    if (key.isEmpty) return;
    setState(() => _connectingItad = true);
    await context.read<WishlistState>().connect(key);
    setState(() => _connectingItad = false);
    _itadController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final needsSteamSetup = auth.status == AuthStatus.needsApiKey;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSteamSection(auth, needsSteamSetup),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                _buildItchioSection(),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                _buildEpicSection(),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                _buildItadSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSteamSection(AuthState auth, bool needsSetup) {
    if (auth.accounts.isEmpty) {
      return _buildFirstSteamAccountForm(needsSetup);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.videogame_asset),
            const SizedBox(width: 8),
            Text('Steam', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        for (final account in auth.accounts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(account.personaName),
            subtitle: const Text('Verbunden'),
            trailing: IconButton(
              tooltip: 'Konto entfernen',
              icon: const Icon(Icons.link_off),
              onPressed: () =>
                  context.read<AuthState>().removeAccount(account.steamId),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Weiteres Steam-Konto hinzufügen (z. B. einen zweiten Account) — '
          'die Spiele werden gemeinsam in einer Bibliothek angezeigt.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openSteamApiKeyPage,
          icon: const Icon(Icons.open_in_new),
          label: const Text('API-Key für dieses Konto erstellen'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addSteamController,
          decoration: const InputDecoration(
            labelText: 'Steam Web-API-Key des weiteren Kontos',
            border: OutlineInputBorder(),
          ),
        ),
        if (_addSteamError != null) ...[
          const SizedBox(height: 8),
          Text(
            _addSteamError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _addingSteamAccount ? null : _addSteamAccount,
          icon: _addingSteamAccount
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: Text(
            _addingSteamAccount
                ? 'Warte auf Browser…'
                : 'Konto hinzufügen (Steam-Login öffnet sich)',
          ),
        ),
      ],
    );
  }

  Widget _buildFirstSteamAccountForm(bool needsSetup) {
    return Form(
      key: _steamFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.videogame_asset),
              const SizedBox(width: 8),
              Text('Steam', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Um deine Bibliothek zu laden, braucht die App deinen persönlichen, '
            'kostenlosen Steam Web-API-Key. Er wird nur lokal auf diesem Gerät '
            'gespeichert und ausschließlich für direkte Anfragen an Steam verwendet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openSteamApiKeyPage,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Eigenen API-Key bei Steam erstellen'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _steamController,
            decoration: const InputDecoration(
              labelText: 'Steam Web-API-Key',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().length != 32) {
                return 'Ein gültiger Steam-API-Key hat 32 Zeichen.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _savingSteam ? null : _saveSteamKey,
            child: _savingSteam
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(needsSetup ? 'Speichern' : 'Aktualisieren'),
          ),
        ],
      ),
    );
  }

  Widget _buildItchioSection() {
    final itchio = context.watch<ItchioState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_rounded),
            const SizedBox(width: 8),
            Text(
              'itch.io (optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (itchio.isConnected) ...[
          for (final account in itchio.accounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('Verbunden als ${account.username}'),
              trailing: IconButton(
                tooltip: 'Konto entfernen',
                icon: const Icon(Icons.link_off),
                onPressed: () =>
                    context.read<ItchioState>().removeAccount(account.apiKey),
              ),
            ),
          Text(
            '${itchio.games.length} Spiele gefunden',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Weiteres itch.io-Konto hinzufügen — die Spiele werden gemeinsam '
            'in einer Bibliothek angezeigt.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ] else
          Text(
            'Bindet zusätzlich deine itch.io-Bibliothek über deinen eigenen, '
            'kostenlosen API-Key ein.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openItchioApiKeyPage,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Eigenen API-Key bei itch.io erstellen'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _itchioController,
          decoration: const InputDecoration(
            labelText: 'itch.io-API-Key',
            border: OutlineInputBorder(),
          ),
        ),
        if (itchio.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            itchio.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _connectingItchio ? null : _connectItchio,
          child: _connectingItchio
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(itchio.isConnected ? 'Konto hinzufügen' : 'Verbinden'),
        ),
      ],
    );
  }

  Widget _buildEpicSection() {
    final epic = context.watch<EpicState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.games_outlined),
            const SizedBox(width: 8),
            Text(
              'Epic Games (optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!Platform.isWindows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Die Epic-Integration liest lokale Dateien des Epic Games Launcher und '
              'ruft das Legendary-CLI-Tool auf — beides funktioniert nur unter Windows, '
              'nicht auf diesem Gerät.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Text(
          'Epic bietet keine offizielle Bibliotheks-API. Ohne weitere Einrichtung zeigt die '
          'App automatisch alle Spiele, die aktuell über den Epic Games Launcher installiert '
          'sind (rein lokal, kein Login nötig). Für deine komplette Bibliothek (auch nicht '
          'installierte Spiele) kannst du zusätzlich das Community-Tool "Legendary" einrichten:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        const _LegendarySetupSteps(),
        const SizedBox(height: 16),
        if (epic.legendaryAvailable && epic.legendaryAuthenticated)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text('Legendary verbunden als ${epic.legendaryUsername}'),
            subtitle: Text('${epic.games.length} Spiele gefunden'),
          )
        else if (epic.legendaryAvailable)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: Colors.orange),
            title: Text('Legendary gefunden, aber nicht angemeldet'),
            subtitle: Text(
              'Führe "legendary auth" oder "legendary auth --import" aus.',
            ),
          )
        else if (epic.hasScanned)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Legendary nicht gefunden'),
            subtitle: Text(
              '${epic.games.length} lokal installierte Epic-Spiele über den offiziellen '
              'Launcher erkannt.',
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: epic.isLoading
              ? null
              : () => context.read<EpicState>().refresh(),
          icon: epic.isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Status aktualisieren'),
        ),
      ],
    );
  }

  Widget _buildItadSection() {
    final wishlist = context.watch<WishlistState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.price_check),
            const SizedBox(width: 8),
            Text(
              'IsThereAnyDeal (optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (wishlist.isConnected) ...[
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Verbunden'),
            subtitle: Text(
              'Preisvergleich, Tiefstpreise und Preisalarm-Wishlist sind aktiv.',
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.read<WishlistState>().disconnect(),
            icon: const Icon(Icons.link_off),
            label: const Text('IsThereAnyDeal trennen'),
          ),
        ] else ...[
          Text(
            'Zeigt Preisvergleiche und historische Tiefstpreise über alle Stores '
            'hinweg und ermöglicht eine Wishlist mit Preisalarm. Ein Key reicht — '
            'die Preisdaten sind für jeden Key identisch, ein zweiter Account bringt '
            'hier keinen zusätzlichen Nutzen.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openItadApiKeyPage,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Eigenen API-Key bei IsThereAnyDeal erstellen'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _itadController,
            decoration: const InputDecoration(
              labelText: 'IsThereAnyDeal-API-Key',
              border: OutlineInputBorder(),
            ),
          ),
          if (wishlist.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              wishlist.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _connectingItad ? null : _connectItad,
            child: _connectingItad
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verbinden'),
          ),
        ],
      ],
    );
  }
}

class _LegendarySetupSteps extends StatelessWidget {
  const _LegendarySetupSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. In einem Terminal installieren:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SelectableText(
            'pip install legendary-gl',
            style: TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Text(
            '2. Einmalig anmelden (wenn der offizielle Epic-Launcher bereits '
            'installiert und eingeloggt ist, geht das ohne Browser-Login):',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SelectableText(
            'legendary auth --import',
            style: TextStyle(fontFamily: 'monospace'),
          ),
          Text(
            '  (sonst: legendary auth)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '3. Danach hier auf "Status aktualisieren" tippen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
