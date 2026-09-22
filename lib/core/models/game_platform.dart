import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The storefront a game was pulled from — drives the badge/filter UI.
/// [logoAsset] is the store's real brand mark (single-colour SVG from
/// Simple Icons), tinted at render time via [PlatformLogo].
enum GamePlatform {
  steam(
    'Steam',
    Color(0xFF1B2838),
    Icons.videogame_asset,
    'assets/brands/steam.svg',
  ),
  itchio(
    'itch.io',
    Color(0xFFFA5C5C),
    Icons.grid_view_rounded,
    'assets/brands/itchio.svg',
  ),
  epic(
    'Epic',
    Color(0xFF2A2A2A),
    Icons.games_outlined,
    'assets/brands/epic.svg',
  ),
  xbox(
    'Xbox',
    Color(0xFF107C10),
    Icons.sports_esports,
    'assets/brands/xbox.svg',
  );

  const GamePlatform(this.label, this.color, this.icon, this.logoAsset);

  final String label;
  final Color color;
  final IconData icon;
  final String logoAsset;
}

/// The store's brand logo, tinted to [color] (white by default so it reads
/// on the coloured badge background).
class PlatformLogo extends StatelessWidget {
  const PlatformLogo(
    this.platform, {
    super.key,
    this.size = 12,
    this.color = Colors.white,
  });

  final GamePlatform platform;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      platform.logoAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: platform.label,
    );
  }
}
