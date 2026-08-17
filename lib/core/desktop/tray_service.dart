import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Adds a Windows system-tray icon so GameLib can keep running in the
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
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon('assets/icons/tray_icon.ico');
    await trayManager.setToolTip('GameLib');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'GameLib anzeigen'),
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
