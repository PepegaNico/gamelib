import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Adds a Windows system-tray icon so GameZer can keep running in the
/// background: closing the window hides it instead of quitting, with a
/// tray menu to reopen or fully exit. No-op on every other platform.
class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final instance = TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    // Native frame off — ZerTitleBar draws its own (see title_bar.dart).
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(const Size(960, 600));
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon('assets/icons/tray_icon.ico');
    await trayManager.setToolTip('GameZer');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'GameZer anzeigen'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Beenden'),
        ],
      ),
    );
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
      case 'quit':
        await windowManager.setPreventClose(false);
        await windowManager.close();
    }
  }
}
