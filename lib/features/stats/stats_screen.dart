import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../domain/services/statistics.dart';
import '../reports/period_selector.dart';
import 'stats_providers.dart';

/// At-a-glance statistics for the selected period. Shares the period control
/// with Reports so switching day/week/month/custom updates both.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider).valueOrNull ?? SessionStats.empty;
    final goal = ref.watch(weeklyGoalProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Statystyki')),
      body: Column(
        children: [
          const PeriodSelector(),
          if (goal != null) _WeeklyGoalCard(goal: goal),
          const SizedBox(height: 4),
          Expanded(
            child: stats.sessionCount == 0
                ? const Center(child: Text('Brak danych w tym okresie'))
                : GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _FocusCard(score: stats.focusScore),
                      _StatCard(
                        icon: Icons.timer_outlined,
                        label: 'Zmierzony czas',
                        value: formatDurationShort(stats.totalTracked),
                      ),
                      _StatCard(
                        icon: Icons.trending_up,
                        label: 'Najdłuższa sesja',
                        value: formatDurationShort(stats.longestSession),
                      ),
                      _StatCard(
                        icon: Icons.straighten,
                        label: 'Średnia sesja',
                        value: formatDurationShort(stats.averageSession),
                      ),
                      _StatCard(
                        icon: Icons.tag,
                        label: 'Liczba sesji',
                        value: '${stats.sessionCount}',
                      ),
                      _StatCard(
                        icon: Icons.swap_horiz,
                        label: 'Przełączenia projektów',
                        value: '${stats.projectSwitches}',
                      ),
                      _StatCard(
                        icon: Icons.hourglass_empty,
                        label: 'Czas niezmierzony',
                        value: formatDurationShort(stats.untracked),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.goal});

  final WeeklyGoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (goal.fraction * 100).round();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  goal.reached ? Icons.emoji_events : Icons.flag_outlined,
                  color: goal.reached ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text('Cel tygodniowy',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('$percent%',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.fraction,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal.reached
                  ? 'Osiągnięto ${formatDurationShort(goal.tracked)} z ${formatDurationShort(goal.goal)} 🎉'
                  : '${formatDurationShort(goal.tracked)} z ${formatDurationShort(goal.goal)} · zostało ${formatDurationShort(goal.remaining)}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: scheme.primary),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.center_focus_strong, color: scheme.onPrimaryContainer),
            Text('$score',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    )),
            Text('Focus Score',
                style: TextStyle(color: scheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}
