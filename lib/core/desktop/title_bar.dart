import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_theme.dart';

/// Custom window title bar for Windows, replacing the native grey frame
/// (hidden in TrayService.init): draggable brand strip plus the three
/// window buttons. Renders nothing on other platforms.
class ZerTitleBar extends StatefulWidget {
  const ZerTitleBar({super.key});

  static const height = 36.0;

  @override
  State<ZerTitleBar> createState() => _ZerTitleBarState();
}

class _ZerTitleBarState extends State<ZerTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) return;
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) setState(() => _maximized = value);
    });
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    return Material(
      color: zerSurface,
      child: SizedBox(
        height: ZerTitleBar.height,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: zerAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GameZer',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: zerTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            WindowCaptionButton.minimize(
              brightness: Brightness.dark,
              onPressed: () => windowManager.minimize(),
            ),
            _maximized
                ? WindowCaptionButton.unmaximize(
                    brightness: Brightness.dark,
                    onPressed: () => windowManager.unmaximize(),
                  )
                : WindowCaptionButton.maximize(
                    brightness: Brightness.dark,
                    onPressed: () => windowManager.maximize(),
                  ),
            // Close hides to the tray (see TrayService.onWindowClose).
            WindowCaptionButton.close(
              brightness: Brightness.dark,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}
