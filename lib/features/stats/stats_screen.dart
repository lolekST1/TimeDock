import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../domain/services/report_range.dart';
import '../../domain/services/statistics.dart';
import '../reports/report_providers.dart';
import 'stats_providers.dart';

/// At-a-glance statistics for the selected period. Shares the period control
/// with Reports so switching day/week/month updates both.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final range = ref.watch(reportRangeProvider);
    final stats = ref.watch(statsProvider).valueOrNull ?? SessionStats.empty;

    return Scaffold(
      appBar: AppBar(title: const Text('Statystyki')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ReportPeriod>(
              segments: const [
                ButtonSegment(value: ReportPeriod.day, label: Text('Dzień')),
                ButtonSegment(value: ReportPeriod.week, label: Text('Tydzień')),
                ButtonSegment(value: ReportPeriod.month, label: Text('Miesiąc')),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(reportPeriodProvider.notifier).state = s.first,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(ref, period, -1),
              ),
              Text(_rangeLabel(period, range),
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(ref, period, 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  void _shift(WidgetRef ref, ReportPeriod period, int direction) {
    final anchor = ref.read(reportAnchorProvider);
    ref.read(reportAnchorProvider.notifier).state =
        ReportRangeCalculator.shift(period, anchor, direction);
  }

  String _rangeLabel(ReportPeriod period, ReportRange range) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    switch (period) {
      case ReportPeriod.day:
        return '${d(range.firstDay)}.${range.firstDay.year}';
      case ReportPeriod.week:
        return '${d(range.firstDay)} – ${d(range.lastDay)}';
      case ReportPeriod.month:
        const months = [
          'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
          'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
        ];
        return '${months[range.firstDay.month - 1]} ${range.firstDay.year}';
    }
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
