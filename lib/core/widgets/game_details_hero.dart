import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../models/game_platform.dart';

/// Full-bleed header shared by every game detail screen (Steam, Epic,
/// itch.io): key art fading into the page, back button, store badge,
/// title, stat pills and the primary actions — same look as the library
/// hero banner.
class GameDetailsHero extends StatelessWidget {
  const GameDetailsHero({
    super.key,
    required this.imageUrl,
    this.fallbackImageUrl,
    required this.platform,
    required this.title,
    this.stats = const [],
    this.actions = const [],
  });

  final String imageUrl;

  /// Shown when [imageUrl] fails to load (e.g. a Steam game without
  /// library_hero art).
  final String? fallbackImageUrl;
  final GamePlatform platform;
  final String title;
  final List<(IconData, String)> stats;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            platform.color,
            Color.lerp(platform.color, Colors.black, 0.6)!,
          ],
        ),
      ),
    );

    Widget image(String url, Widget Function() onError) => url.isEmpty
        ? onError()
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            placeholder: (_, _) => Container(color: zerSurfaceHigh),
            errorWidget: (_, _, _) => onError(),
          );

    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image(imageUrl, () => image(fallbackImageUrl ?? '', placeholder)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x22000000), zerBackground],
                stops: [0, 0.35, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
                stops: const [0, 0.7],
              ),
            ),
          ),
          if (Navigator.of(context).canPop())
            Positioned(
              left: 20,
              top: 16,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Zurück',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(platform: platform),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontWeight: FontWeight.w800,
                    fontSize: 38,
                    height: 1.08,
                    color: Colors.white,
                  ),
                ),
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (icon, label) in stats)
                        _StatPill(icon: icon, label: label),
                    ],
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: actions),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page body under a [GameDetailsHero]: left-aligned with the hero text,
/// width-capped so long descriptions stay readable.
class GameDetailsBody extends StatelessWidget {
  const GameDetailsBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.platform});

  final GamePlatform platform;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlatformLogo(platform, size: 14),
          const SizedBox(width: 6),
          Text(
            platform.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: zerMonoTextStyle.copyWith(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
