import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'stats_state.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiken')),
      body: stats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!stats.hasEnoughData)
                        _EmptyState(distinctDays: stats.distinctDaysRecorded)
                      else ...[
                        _WeekChartCard(stats: stats),
                        const SizedBox(height: 24),
                        _TopGamesCard(stats: stats),
                        const SizedBox(height: 24),
                        _YearReviewCard(stats: stats),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.distinctDays});

  final int distinctDays;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.query_stats, size: 48),
          const SizedBox(height: 16),
          Text(
            'Noch nicht genug Daten',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Steam liefert keine Spielzeit-Historie — die App sammelt sie erst ab jetzt, '
            'jedes Mal wenn du sie öffnest. Bisher aufgezeichnete Tage: $distinctDays.\n'
            'Nach ein paar Tagen aktiver Nutzung erscheinen hier Trends.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeekChartCard extends StatelessWidget {
  const _WeekChartCard({required this.stats});

  final StatsState stats;

  @override
  Widget build(BuildContext context) {
    final days = stats.dailyHoursLast7Days;
    final maxValue = days.fold<double>(1, (m, e) => e.value > m ? e.value : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diese Woche', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${stats.weeklyTotalHours.toStringAsFixed(1)} h gesamt',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (day.value > 0)
                              Text(
                                day.value.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 4),
                            Container(
                              height: (day.value / maxValue * 90).clamp(2, 90),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              StatsScreen._weekdayLabels[day.key.weekday - 1],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopGamesCard extends StatelessWidget {
  const _TopGamesCard({required this.stats});

  final StatsState stats;

  @override
  Widget build(BuildContext context) {
    final topGames = stats.topGamesThisYear();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meistgespielt ${DateTime.now().year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (topGames.isEmpty)
              Text(
                'Noch keine Daten für dieses Jahr.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final entry in topGames)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(entry.key, overflow: TextOverflow.ellipsis),
                      ),
                      Text('${entry.value.toStringAsFixed(1)} h'),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _YearReviewCard extends StatelessWidget {
  const _YearReviewCard({required this.stats});

  final StatsState stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jahresrückblick ${DateTime.now().year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${stats.totalHoursThisYear.toStringAsFixed(1)} Stunden seit Beginn der Aufzeichnung gespielt.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Wird über das Jahr vollständiger, je länger die App genutzt wird.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
