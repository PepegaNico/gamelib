import 'package:flutter/foundation.dart';

import '../../core/xbox/ms_store_catalog_service.dart';
import '../../core/xbox/xbox_game.dart';
import '../../core/xbox/xbox_local_scanner.dart';

/// Locally installed Xbox app / Microsoft Store games (Windows only).
class XboxState extends ChangeNotifier {
  XboxState({XboxLocalScanner? scanner, MsStoreCatalogService? catalog})
    : _scanner = scanner ?? XboxLocalScanner(),
      _catalog = catalog ?? MsStoreCatalogService();

  final XboxLocalScanner _scanner;
  final MsStoreCatalogService _catalog;

  List<XboxGame> games = [];
  bool isLoading = false;
  bool hasScanned = false;

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();

    final found = await _scanner.listInstalledGames();
    await Future.wait(found.map(_catalog.enrich));
    games = found..sort((a, b) => a.name.compareTo(b.name));

    hasScanned = true;
    isLoading = false;
    notifyListeners();
  }
}
