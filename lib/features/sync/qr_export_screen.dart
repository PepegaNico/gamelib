import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/sync/qr_credentials_payload.dart';
import '../auth/auth_state.dart';
import '../itchio/itchio_state.dart';
import '../wishlist/wishlist_state.dart';
import 'sync_state.dart';

enum _Target { iphone, otherDevice }

/// Shows a QR code for pairing another device:
/// - "iPhone": only the Cloud-Sync token — all the iOS app needs, and short
///   enough to stay easily scannable off a monitor.
/// - "Anderer PC": every connected account's credentials, so another
///   device can scan it (see QrImportScreen) instead of re-entering every
///   API key by hand.
class QrExportScreen extends StatefulWidget {
  const QrExportScreen({super.key});

  @override
  State<QrExportScreen> createState() => _QrExportScreenState();
}

class _QrExportScreenState extends State<QrExportScreen> {
  _Target _target = _Target.iphone;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final itchio = context.watch<ItchioState>();
    final wishlist = context.watch<WishlistState>();
    final sync = context.watch<SyncState>();
    final syncToken = sync.refreshTokenForPairing;

    final QrCredentialsPayload? payload = switch (_target) {
      _Target.iphone =>
        syncToken == null ? null : QrCredentialsPayload.pairingOnly(syncToken),
      _Target.otherDevice => QrCredentialsPayload(
        steamAccounts: [
          for (final a in auth.accounts) (steamId: a.steamId, apiKey: a.apiKey),
        ],
        itchioApiKeys: [for (final a in itchio.accounts) a.apiKey],
        itadApiKey: wishlist.apiKey,
        syncRefreshToken: syncToken,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Als QR-Code anzeigen')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<_Target>(
                  segments: const [
                    ButtonSegment(
                      value: _Target.iphone,
                      icon: Icon(Icons.phone_iphone),
                      label: Text('iPhone'),
                    ),
                    ButtonSegment(
                      value: _Target.otherDevice,
                      icon: Icon(Icons.computer),
                      label: Text('Anderer PC'),
                    ),
                  ],
                  selected: {_target},
                  onSelectionChanged: (value) =>
                      setState(() => _target = value.first),
                ),
                const SizedBox(height: 24),
                if (payload == null || payload.isEmpty)
                  Text(
                    _target == _Target.iphone
                        ? 'Melde dich zuerst unter Einstellungen → Cloud-Sync '
                              'an. Das iPhone verbindet sich über dein '
                              'Cloud-Sync-Konto.'
                        : 'Es sind noch keine Konten verbunden — verbinde '
                              'zuerst mindestens ein Steam-, itch.io- oder '
                              'IsThereAnyDeal-Konto.',
                    textAlign: TextAlign.center,
                  )
                else
                  _QrPanel(
                    data: payload.encode(),
                    instructions: _target == _Target.iphone
                        ? 'In GameZer auf dem iPhone: Einstellungen → '
                              '"QR-Code scannen". Halte das iPhone so, dass '
                              'der Code den Rahmen gut ausfüllt.'
                        : 'Scanne diesen Code auf deinem anderen Gerät '
                              '(Einstellungen → "QR-Code scannen"), um alle '
                              'verbundenen Konten dorthin zu übertragen.',
                    summary: _target == _Target.iphone
                        ? 'Cloud-Sync-Konto ${sync.email ?? ''}'
                        : '${auth.accounts.length} Steam-, '
                              '${itchio.accounts.length} itch.io-Konto(en)'
                              '${wishlist.hasOwnKey ? " + IsThereAnyDeal" : ""}'
                              '${syncToken != null ? " + Cloud-Sync" : ""}',
                    warning: _target == _Target.iphone
                        ? 'Verbindet ein Gerät mit deinem Cloud-Sync-Konto — '
                              'nicht als Screenshot teilen.'
                        : 'Enthält deine API-Keys im Klartext — nicht als '
                              'Screenshot teilen oder öffentlich zeigen.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({
    required this.data,
    required this.instructions,
    required this.summary,
    required this.warning,
  });

  final String data;
  final String instructions;
  final String summary;
  final String warning;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          instructions,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        // Large and with a generous white quiet zone — phone cameras read
        // codes off a monitor far more reliably when modules are big.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.L,
            size: 380,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(summary, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Text(
          warning,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: data));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('In die Zwischenablage kopiert.')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Als Text kopieren (Fallback)'),
        ),
      ],
    );
  }
}
