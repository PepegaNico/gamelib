import 'package:flutter/material.dart';

/// The storefront a game was pulled from. Only Steam is wired up today;
/// Epic (and others) plug into the same badge/filter UI once their library
/// sync lands.
enum GamePlatform {
  steam('Steam', Color(0xFF1B2838), Icons.videogame_asset),
  itchio('itch.io', Color(0xFFFA5C5C), Icons.grid_view_rounded),
  epic('Epic', Color(0xFF2A2A2A), Icons.games_outlined);

  const GamePlatform(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}
