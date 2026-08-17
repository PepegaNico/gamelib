import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/sync/qr_credentials_payload.dart';
import '../auth/auth_state.dart';
import '../itchio/itchio_state.dart';
import '../wishlist/wishlist_state.dart';

/// Scans a QR code produced by QrExportScreen on another device and imports
/// every account it contains — Steam accounts skip the usual OpenID
/// browser round-trip since the SteamID is already known and trusted.
class QrImportScreen extends StatefulWidget {
  const QrImportScreen({super.key});

  @override
  State<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends State<QrImportScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null) return;

    final QrCredentialsPayload payload;
    try {
      payload = QrCredentialsPayload.decode(raw);
    } catch (_) {
      return; // Not a GameLib sync code — keep scanning.
    }

    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    setState(() => _importing = true);

    await _importPayload(payload);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _importPayload(QrCredentialsPayload payload) async {
    final auth = context.read<AuthState>();
    final itchio = context.read<ItchioState>();
    final wishlist = context.read<WishlistState>();

    var imported = 0;
    var failed = 0;

    for (final account in payload.steamAccounts) {
      final error = await auth.importAccount(
        steamId: account.steamId,
        apiKey: account.apiKey,
      );
      if (error == null) {
        imported++;
      } else {
        failed++;
      }
    }
    for (final key in payload.itchioApiKeys) {
      final error = await itchio.addAccount(key);
      if (error == null) {
        imported++;
      } else {
        failed++;
      }
    }
    if (payload.itadApiKey != null) {
      await wishlist.connect(payload.itadApiKey!);
      imported++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? '$imported Konto(en) erfolgreich importiert.'
              : '$imported Konto(en) importiert, $failed fehlgeschlagen.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR-Code scannen')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Richte die Kamera auf den QR-Code des anderen Geräts',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          if (_importing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
