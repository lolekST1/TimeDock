import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../core/ui/donut_gauge.dart';
import '../../core/ui/metric_bar.dart';
import '../../core/ui/td_card.dart';
import '../../core/ui/td_tokens.dart';
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const PeriodSelector(),
          const SizedBox(height: 14),
          if (goal != null) ...[
            _WeeklyGoalCard(goal: goal),
            const SizedBox(height: 12),
          ],
          if (stats.sessionCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('Brak danych w tym okresie')),
            )
          else ...[
            _FocusHero(score: stats.focusScore),
            const SizedBox(height: 12),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 11,
                crossAxisSpacing: 11,
                mainAxisExtent: 108,
              ),
              children: [
                _MiniStatCard(
                  icon: Icons.timer_outlined,
                  label: 'Zmierzony czas',
                  value: formatDurationShort(stats.totalTracked),
                ),
                _MiniStatCard(
                  icon: Icons.trending_up,
                  label: 'Najdłuższa sesja',
                  value: formatDurationShort(stats.longestSession),
                ),
                _MiniStatCard(
                  icon: Icons.straighten,
                  label: 'Średnia sesja',
                  value: formatDurationShort(stats.averageSession),
                ),
                _MiniStatCard(
                  icon: Icons.tag,
                  label: 'Liczba sesji',
                  value: '${stats.sessionCount}',
                ),
                _MiniStatCard(
                  icon: Icons.swap_horiz,
                  label: 'Przełączenia projektów',
                  value: '${stats.projectSwitches}',
                ),
                _MiniStatCard(
                  icon: Icons.hourglass_empty,
                  label: 'Czas niezmierzony',
                  value: formatDurationShort(stats.untracked),
                  tone: _Tone.warn,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusHero extends StatelessWidget {
  const _FocusHero({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final (color, ink, bg, verdict) = score >= 75
        ? (td.good, td.goodInk, td.goodBg, 'Świetne skupienie')
        : score >= 50
            ? (td.info, td.infoInk, td.infoBg, 'Nieźle')
            : (td.warn, td.warnInk, td.warnBg, 'Sporo przełączeń');

    return TdCard(
      child: Row(
        children: [
          DonutGauge(
            value: score / 100,
            color: color,
            size: 96,
            center: Text(
              '$score',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Focus Score',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Udział czasu w sesjach ≥ 25 min. Im mniej rozdrobnienia, tym wyżej.',
                  style: TextStyle(fontSize: 12.5, color: td.faint, height: 1.35),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(verdict,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { neutral, warn }

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.tone = _Tone.neutral,
  });

  final IconData icon;
  final String label;
  final String value;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final accent = tone == _Tone.warn ? td.warn : context.cs.primary;
    final accentBg = tone == _Tone.warn ? td.warnBg : context.cs.primaryContainer;

    return TdCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: td.faint, fontSize: 12, fontWeight: FontWeight.w600),
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
    final td = context.td;
    final percent = (goal.fraction * 100).round();
    final color = goal.reached ? td.good : context.cs.primary;

    return TdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(goal.reached ? Icons.emoji_events : Icons.flag_outlined,
                  color: color, size: 20),
              const SizedBox(width: 8),
              const Text('Cel tygodniowy',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Text('$percent%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          MetricBar(value: goal.fraction, color: color),
          const SizedBox(height: 10),
          Text(
            goal.reached
                ? 'Osiągnięto ${formatDurationShort(goal.tracked)} z ${formatDurationShort(goal.goal)} 🎉'
                : '${formatDurationShort(goal.tracked)} z ${formatDurationShort(goal.goal)} · zostało ${formatDurationShort(goal.remaining)}',
            style: TextStyle(color: td.faint, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
