import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/sync/qr_credentials_payload.dart';
import '../auth/auth_state.dart';
import '../itchio/itchio_state.dart';
import '../wishlist/wishlist_state.dart';

/// Shows a QR code encoding every connected account's credentials so
/// another device can scan it (see QrImportScreen) instead of re-entering
/// every API key by hand.
class QrExportScreen extends StatelessWidget {
  const QrExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final itchio = context.watch<ItchioState>();
    final wishlist = context.watch<WishlistState>();

    final payload = QrCredentialsPayload(
      steamAccounts: [
        for (final a in auth.accounts) (steamId: a.steamId, apiKey: a.apiKey),
      ],
      itchioApiKeys: [for (final a in itchio.accounts) a.apiKey],
      itadApiKey: wishlist.apiKey,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Als QR-Code anzeigen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: payload.isEmpty
                ? const Text(
                    'Es sind noch keine Konten verbunden — verbinde zuerst '
                    'mindestens ein Steam-, itch.io- oder IsThereAnyDeal-Konto.',
                    textAlign: TextAlign.center,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scanne diesen Code auf deinem anderen Gerät '
                        '(Einstellungen → "QR-Code scannen"), um alle '
                        'verbundenen Konten dorthin zu übertragen.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: payload.encode(),
                          version: QrVersions.auto,
                          size: 260,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${auth.accounts.length} Steam-, ${itchio.accounts.length} '
                        'itch.io-Konto(en)${wishlist.hasOwnKey ? " + IsThereAnyDeal" : ""}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enthält deine API-Keys im Klartext — nicht als Screenshot '
                        'teilen oder öffentlich zeigen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: payload.encode()),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'In die Zwischenablage kopiert.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Als Text kopieren (Fallback)'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
