import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/steam/steam_achievement.dart';

class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.achievements});

  final List<SteamAchievement> achievements;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.achieved).length;
    final progress = achievements.isEmpty
        ? 0.0
        : unlocked / achievements.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Erfolge', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ),
            const SizedBox(width: 12),
            Text('$unlocked / ${achievements.length}'),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            childAspectRatio: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 4,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final achievement = achievements[index];
            return Opacity(
              opacity: achievement.achieved ? 1 : 0.45,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: achievement.achieved
                          ? achievement.iconUrl
                          : achievement.iconGrayUrl,
                      width: 32,
                      height: 32,
                      errorWidget: (context, url, error) =>
                          const SizedBox(width: 32, height: 32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      achievement.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
