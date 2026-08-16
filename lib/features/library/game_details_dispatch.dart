import 'package:flutter/material.dart';

import '../../core/epic/epic_game.dart';
import '../../core/itchio/itchio_game.dart';
import '../../core/models/library_game.dart';
import '../../core/steam/steam_game.dart';
import 'epic_game_details_screen.dart';
import 'game_details_screen.dart';
import 'itchio_game_details_screen.dart';

/// Opens the right detail screen for whichever store [game] came from.
void pushGameDetails(BuildContext context, LibraryGame game) {
  if (game is SteamGame) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GameDetailsScreen(game: game)));
  } else if (game is ItchioGame) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItchioGameDetailsScreen(game: game)),
    );
  } else if (game is EpicGame) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EpicGameDetailsScreen(game: game)),
    );
  }
}
