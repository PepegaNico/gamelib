import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'core/desktop/tray_service.dart';
import 'core/notifications/background_price_check.dart';
import 'core/widgets/build_banner.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/login_screen.dart';
import 'features/epic/epic_state.dart';
import 'features/itchio/itchio_state.dart';
import 'features/library/library_screen.dart';
import 'features/library/library_state.dart';
import 'features/settings/settings_screen.dart';
import 'features/sync/sync_state.dart';
import 'features/updates/updates_state.dart';
import 'features/wishlist/wishlist_state.dart';

/// Runs when iOS relaunches the app headlessly (fully terminated) just to
/// perform a background fetch — must stay a top-level function so it
/// survives AOT tree-shaking and can run without any of main()'s state.
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  if (task.timeout) {
    BackgroundFetch.finish(task.taskId);
    return;
  }
  await BackgroundPriceCheck.run();
  BackgroundFetch.finish(task.taskId);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TrayService.instance.init();
  if (Platform.isIOS) {
    await _configureBackgroundPriceChecks();
  }
  runApp(const GameLibApp());
}

/// Periodically wakes the app in the background (timing is opportunistic —
/// iOS decides exactly when) to check wishlist prices and fire a local
/// notification for any newly-triggered alert. See BackgroundPriceCheck.
Future<void> _configureBackgroundPriceChecks() async {
  await BackgroundFetch.configure(
    BackgroundFetchConfig(
      minimumFetchInterval: 60,
      stopOnTerminate: false,
      enableHeadless: true,
      requiredNetworkType: NetworkType.ANY,
    ),
    (String taskId) async {
      await BackgroundPriceCheck.run();
      BackgroundFetch.finish(taskId);
    },
    (String taskId) async {
      BackgroundFetch.finish(taskId);
    },
  );
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class GameLibApp extends StatelessWidget {
  const GameLibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()..restore()),
        ChangeNotifierProvider(create: (_) => LibraryState()),
        ChangeNotifierProvider(create: (_) => UpdatesState()),
        ChangeNotifierProvider(create: (_) => ItchioState()..restore()),
        ChangeNotifierProvider(create: (_) => EpicState()),
        ChangeNotifierProvider(create: (_) => WishlistState()..restore()),
        ChangeNotifierProvider(create: (_) => SyncState()..restore()),
      ],
      child: MaterialApp(
        title: 'GameLib',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _RootScreen(),
        builder: (context, child) =>
            BuildBanner(child: child ?? const SizedBox.shrink()),
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
