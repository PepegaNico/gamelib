import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videogame_asset, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Mit Steam anmelden',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Öffnet den Steam-Login im Browser. Deine Bibliothek wird '
                  'danach direkt von Steam geladen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (auth.errorMessage != null) ...[
                  Text(
                    auth.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: auth.isSigningIn
                      ? null
                      : () => auth.signInWithSteam(),
                  icon: auth.isSigningIn
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    auth.isSigningIn
                        ? 'Warte auf Browser…'
                        : 'Mit Steam anmelden',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.read<AuthState>().removeApiKey(),
                  child: const Text('Anderen API-Key verwenden'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
