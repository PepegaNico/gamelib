import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_state.dart';
import '../epic/epic_state.dart';
import '../itchio/itchio_state.dart';
import '../sync/qr_export_screen.dart';
import '../sync/qr_import_screen.dart';
import '../sync/sync_state.dart';
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

  final _syncEmailController = TextEditingController();
  final _syncPasswordController = TextEditingController();
  bool _syncIsRegistering = false;

  @override
  void dispose() {
    _steamController.dispose();
    _addSteamController.dispose();
    _itchioController.dispose();
    _itadController.dispose();
    _syncEmailController.dispose();
    _syncPasswordController.dispose();
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
      setState(
        () => _addSteamError = 'Ein gültiger Steam-API-Key hat 32 Zeichen.',
      );
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

  Future<void> _submitSyncAuth() async {
    final email = _syncEmailController.text.trim();
    final password = _syncPasswordController.text;
    if (email.isEmpty || password.isEmpty) return;

    final sync = context.read<SyncState>();
    final error = _syncIsRegistering
        ? await sync.register(email, password)
        : await sync.login(email, password);
    if (!mounted || error != null) return;

    _syncEmailController.clear();
    _syncPasswordController.clear();
    await _runSync();
  }

  Future<void> _sendPasswordReset() async {
    final email = _syncEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst deine E-Mail-Adresse eintragen.'),
        ),
      );
      return;
    }
    final error = await context.read<SyncState>().sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'E-Mail zum Zurücksetzen des Passworts wurde verschickt.',
        ),
      ),
    );
  }

  Future<void> _runSync() async {
    final sync = context.read<SyncState>();
    final error = await sync.sync(
      auth: context.read<AuthState>(),
      itchio: context.read<ItchioState>(),
      wishlist: context.read<WishlistState>(),
      epic: context.read<EpicState>(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Synchronisiert.')));
  }

  Widget _statusChip(String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.check_circle, size: 16, color: Colors.green),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.green)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final itchio = context.watch<ItchioState>();
    final epic = context.watch<EpicState>();
    final wishlist = context.watch<WishlistState>();
    final sync = context.watch<SyncState>();
    final needsSteamSetup = auth.status == AuthStatus.needsApiKey;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.accounts.isEmpty)
                  _buildFirstSteamAccountForm(needsSteamSetup)
                else
                  _SettingsSection(
                    icon: Icons.videogame_asset,
                    title: 'Steam',
                    status: _statusChip('${auth.accounts.length} Konto(en)'),
                    children: _buildSteamSectionChildren(auth),
                  ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.grid_view_rounded,
                  title: 'itch.io',
                  status: itchio.isConnected
                      ? _statusChip('${itchio.accounts.length} Konto(en)')
                      : null,
                  children: _buildItchioSectionChildren(itchio),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.games_outlined,
                  title: 'Epic Games',
                  status: _epicStatusChip(epic, sync),
                  children: _buildEpicSectionChildren(epic, sync),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.price_check,
                  title: 'IsThereAnyDeal',
                  status: wishlist.hasOwnKey
                      ? _statusChip('Eigener Key')
                      : (wishlist.isConnected
                            ? _statusChip('Gemeinsamer Key')
                            : null),
                  children: _buildItadSectionChildren(wishlist),
                ),
                const SizedBox(height: 24),
                Text(
                  'Geräte-Sync',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _SettingsSection(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Cloud-Sync',
                  status: sync.status == SyncStatus.loggedIn
                      ? _statusChip(sync.email ?? 'Angemeldet')
                      : null,
                  initiallyExpanded: sync.status != SyncStatus.loggedIn,
                  children: _buildCloudSyncSectionChildren(sync),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.qr_code_2,
                  title: 'QR-Code-Übertragung',
                  children: _buildQrSectionChildren(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _epicStatusChip(EpicState epic, SyncState sync) {
    if (epic.games.isNotEmpty) {
      return _statusChip('${epic.games.length} Spiele');
    }
    if (sync.syncedEpicGames.isNotEmpty) {
      return _statusChip('${sync.syncedEpicGames.length} Spiele (Sync)');
    }
    return null;
  }

  List<Widget> _buildCloudSyncSectionChildren(SyncState sync) {
    if (sync.status == SyncStatus.loggedIn) {
      return [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text('Angemeldet als ${sync.email}'),
          subtitle: const Text(
            'Verbundene Konten werden mit deinen anderen Geräten abgeglichen.',
          ),
        ),
        if (sync.errorMessage != null) ...[
          Text(
            sync.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: sync.isBusy ? null : _runSync,
          icon: sync.isBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: const Text('Jetzt synchronisieren'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.read<SyncState>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Abmelden'),
        ),
      ];
    }

    return [
      Text(
        'Meldet dich mit einem GameLib-Konto an, damit verbundene Steam-/'
        'itch.io-/IsThereAnyDeal-Konten und deine Epic-Bibliothek automatisch '
        'mit deinen anderen Geräten abgeglichen werden — ohne QR-Code, im '
        'Hintergrund bei jedem Aktualisieren.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _syncEmailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'E-Mail',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _syncPasswordController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Passwort (mind. 6 Zeichen)',
          border: OutlineInputBorder(),
        ),
      ),
      if (!_syncIsRegistering)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: sync.isBusy ? null : _sendPasswordReset,
            child: const Text('Passwort vergessen?'),
          ),
        ),
      if (sync.errorMessage != null) ...[
        const SizedBox(height: 8),
        Text(
          sync.errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: sync.isBusy ? null : _submitSyncAuth,
        child: sync.isBusy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_syncIsRegistering ? 'Konto erstellen' : 'Anmelden'),
      ),
      TextButton(
        onPressed: () =>
            setState(() => _syncIsRegistering = !_syncIsRegistering),
        child: Text(
          _syncIsRegistering
              ? 'Ich habe schon ein Konto'
              : 'Neues Konto erstellen',
        ),
      ),
    ];
  }

  List<Widget> _buildQrSectionChildren() {
    final canScan = Platform.isIOS || Platform.isAndroid;

    return [
      Text(
        'Überträgt alle verbundenen Konten (Steam, itch.io, IsThereAnyDeal) '
        'in einem einmaligen Schritt auf ein anderes Gerät, ohne jeden '
        'API-Key erneut einzutippen — als Alternative zum Cloud-Sync.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QrExportScreen()),
        ),
        icon: const Icon(Icons.qr_code),
        label: const Text('Als QR-Code anzeigen'),
      ),
      if (canScan) ...[
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QrImportScreen()),
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('QR-Code scannen'),
        ),
      ],
    ];
  }

  List<Widget> _buildSteamSectionChildren(AuthState auth) {
    return [
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
      const SizedBox(height: 8),
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
    ];
  }

  Widget _buildFirstSteamAccountForm(bool needsSetup) {
    return Form(
      key: _steamFormKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.videogame_asset),
                  const SizedBox(width: 8),
                  Text(
                    'Steam',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Um deine Bibliothek zu laden, braucht die App deinen '
                'persönlichen, kostenlosen Steam Web-API-Key. Er wird nur '
                'lokal auf diesem Gerät gespeichert und ausschließlich für '
                'direkte Anfragen an Steam verwendet.',
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
        ),
      ),
    );
  }

  List<Widget> _buildItchioSectionChildren(ItchioState itchio) {
    return [
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
    ];
  }

  List<Widget> _buildEpicSectionChildren(EpicState epic, SyncState sync) {
    final syncedCount = sync.syncedEpicGames.length;

    return [
      if (!Platform.isWindows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            syncedCount > 0
                ? '$syncedCount Spiele wurden von deinem Windows-PC über '
                      'Cloud-Sync übertragen (nur ansehen/durchsuchen — '
                      'starten geht nur dort, wo der Epic Launcher '
                      'installiert ist).'
                : 'Die Epic-Integration liest lokale Dateien des Epic Games '
                      'Launcher und ruft das Legendary-CLI-Tool auf — beides '
                      'funktioniert nur unter Windows, nicht auf diesem '
                      'Gerät. Sobald du dich auf deinem Windows-PC bei '
                      'Cloud-Sync anmeldest, erscheint deine Epic-Bibliothek '
                      'hier automatisch (nur ansehen, nicht startbar).',
            style: syncedCount > 0
                ? Theme.of(context).textTheme.bodySmall
                : TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      Text(
        'Epic bietet keine offizielle Bibliotheks-API. Ohne weitere '
        'Einrichtung zeigt die App automatisch alle Spiele, die aktuell über '
        'den Epic Games Launcher installiert sind (rein lokal, kein Login '
        'nötig). Für deine komplette Bibliothek (auch nicht installierte '
        'Spiele) kannst du zusätzlich das Community-Tool "Legendary" '
        'einrichten:',
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
            '${epic.games.length} lokal installierte Epic-Spiele über den '
            'offiziellen Launcher erkannt.',
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
    ];
  }

  List<Widget> _buildItadSectionChildren(WishlistState wishlist) {
    return [
      if (wishlist.hasOwnKey) ...[
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('Eigener Key verbunden'),
          subtitle: Text(
            'Preisvergleich, Tiefstpreise und Preisalarm-Wishlist sind aktiv.',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.read<WishlistState>().disconnect(),
          icon: const Icon(Icons.link_off),
          label: const Text('Eigenen Key trennen'),
        ),
      ] else ...[
        if (wishlist.isConnected)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Preisvergleich aktiv (gemeinsamer Key)'),
              subtitle: Text(
                'Funktioniert bereits ohne eigenen Key. Verbinde optional '
                'deinen eigenen, falls das gemeinsame Kontingent mal knapp wird.',
              ),
            ),
          )
        else
          Text(
            'Zeigt Preisvergleiche und historische Tiefstpreise über alle '
            'Stores hinweg und ermöglicht eine Wishlist mit Preisalarm.',
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
    ];
  }
}

/// A collapsible, card-styled settings group — keeps the settings screen
/// scannable at a glance (icon, title, connection status) without forcing
/// every section's full detail into view at once.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
    this.status,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget? status;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon),
          title: Text(title),
          trailing: status == null
              ? const Icon(Icons.expand_more)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    status!,
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more),
                  ],
                ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
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
