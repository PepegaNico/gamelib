import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/login_screen.dart';
import 'features/epic/epic_state.dart';
import 'features/friends/friends_state.dart';
import 'features/itchio/itchio_state.dart';
import 'features/library/library_screen.dart';
import 'features/library/library_state.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_state.dart';
import 'features/sync/sync_state.dart';
import 'features/updates/updates_state.dart';
import 'features/wishlist/wishlist_state.dart';

void main() {
  runApp(const GameLibApp());
}

class GameLibApp extends StatelessWidget {
  const GameLibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()..restore()),
        ChangeNotifierProvider(create: (_) => LibraryState()),
        ChangeNotifierProvider(create: (_) => FriendsState()),
        ChangeNotifierProvider(create: (_) => UpdatesState()),
        ChangeNotifierProvider(create: (_) => ItchioState()..restore()),
        ChangeNotifierProvider(create: (_) => EpicState()),
        ChangeNotifierProvider(create: (_) => StatsState()..load()),
        ChangeNotifierProvider(create: (_) => WishlistState()..restore()),
        ChangeNotifierProvider(create: (_) => SyncState()..restore()),
      ],
      child: MaterialApp(
        title: 'GameLib',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _RootScreen(),
      ),
    );
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.needsApiKey:
        return const SettingsScreen();
      case AuthStatus.needsLogin:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const LibraryScreen();
    }
  }
}
