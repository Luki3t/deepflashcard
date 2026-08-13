import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/languages.dart';
import 'stats_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: statsAsync.when(
        data: (data) => _StatsBody(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.data});
  final StatsData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StreakHero(streak: data.userStat?.currentStreak ?? 0),
        const SizedBox(height: 16),
        _StatGrid(data: data),
        const SizedBox(height: 24),
        Text(
          'Activity — last 90 days',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _Heatmap(activityMap: data.activityMap),
        const SizedBox(height: 24),
        if (data.deckProgress.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Progress per deck',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showDeckProgressInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...data.deckProgress.map((p) => _DeckProgressRow(progress: p)),
        ],
      ],
    );
  }
}

void _showDeckProgressInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Progress per deck'),
      content: const Text(
        'A card counts as "learned" only after 3 correct reviews in a row. '
        'Because reviews are spaced out over time (1 day, then 6 days, then '
        'longer), this takes about a week of study to reach even if you '
        "answer correctly every time — so it's normal for a new deck to "
        'show 0 learned for the first few days.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  streak == 1 ? 'day streak' : 'day streak',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.data});
  final StatsData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total cards', '${data.totalCards}', Icons.style_outlined),
      ('Due now', '${data.dueNow}', Icons.schedule_outlined),
      ('Learned', '${data.learnedCards}', Icons.check_circle_outline),
      (
        'Total reviews',
        '${data.userStat?.totalReviews ?? 0}',
        Icons.replay_outlined,
      ),
      (
        'Longest streak',
        '${data.userStat?.longestStreak ?? 0}',
        Icons.local_fire_department_outlined,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: items
          .map(
            (item) => _StatCard(label: item.$1, value: item.$2, icon: item.$3),
          )
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
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

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.activityMap});
  final Map<DateTime, int> activityMap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Build 90-day grid (13 columns × 7 rows, newest on right)
    final days = List.generate(90, (i) {
      return todayDate.subtract(Duration(days: 89 - i));
    });

    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    Color colorFor(int count) {
      if (count == 0) return surface;
      if (count <= 3) return primary.withValues(alpha: 0.3);
      if (count <= 7) return primary.withValues(alpha: 0.6);
      return primary;
    }

    return SizedBox(
      height: 88,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: days.length,
        itemBuilder: (_, i) {
          final count = activityMap[days[i]] ?? 0;
          return Tooltip(
            message: '${days[i].day}/${days[i].month}: $count reviews',
            child: Container(
              decoration: BoxDecoration(
                color: colorFor(count),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeckProgressRow extends StatelessWidget {
  const _DeckProgressRow({required this.progress});
  final DeckProgress progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progress.deck.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${languageFlag(progress.deck.sourceLanguage)} → '
                '${languageFlag(progress.deck.targetLanguage)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              Text(
                '${progress.learned}/${progress.total}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress.ratio,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
