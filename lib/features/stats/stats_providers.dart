import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/services/report_range.dart';
import '../../domain/services/statistics.dart';
import '../app_state/app_providers.dart';
import '../reports/report_providers.dart';

/// Statistics for the selected workspace and report period, live-updating.
/// Shares the period/anchor with the Reports screen.
final statsProvider = StreamProvider<SessionStats>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceProvider);
  if (workspaceId == null) return Stream.value(SessionStats.empty);

  final range = ref.watch(reportRangeProvider);
  final from = range.firstDay.subtract(const Duration(days: 1));
  final to = range.lastDay.add(const Duration(days: 2));

  return ref
      .watch(sessionRepositoryProvider)
      .watchOverlappingRange(workspaceId, from, to)
      .map((sessions) => StatisticsCalculator.compute(
            sessions: sessions,
            firstDay: range.firstDay,
            lastDay: range.lastDay,
          ));
});

/// Progress toward the selected workspace's weekly goal, for the current week.
/// Null when no goal is set.
class WeeklyGoalProgress {
  const WeeklyGoalProgress({required this.goal, required this.tracked});

  final Duration goal;
  final Duration tracked;

  double get fraction => goal.inSeconds == 0
      ? 0
      : (tracked.inSeconds / goal.inSeconds).clamp(0.0, 1.0);

  bool get reached => tracked >= goal;

  Duration get remaining =>
      tracked >= goal ? Duration.zero : goal - tracked;
}

final weeklyGoalProvider = StreamProvider<WeeklyGoalProgress?>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceProvider);
  if (workspaceId == null) return Stream.value(null);

  final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const [];
  final goalMinutes = workspaces
      .where((w) => w.id == workspaceId)
      .firstOrNull
      ?.weeklyGoalMinutes;
  if (goalMinutes == null || goalMinutes <= 0) return Stream.value(null);

  final now = DateTime.now();
  final range = ReportRangeCalculator.rangeFor(
      ReportPeriod.week, DateTime.utc(now.year, now.month, now.day));
  final from = range.firstDay.subtract(const Duration(days: 1));
  final to = range.lastDay.add(const Duration(days: 2));

  return ref
      .watch(sessionRepositoryProvider)
      .watchOverlappingRange(workspaceId, from, to)
      .map((sessions) {
    final stats = StatisticsCalculator.compute(
      sessions: sessions,
      firstDay: range.firstDay,
      lastDay: range.lastDay,
    );
    return WeeklyGoalProgress(
      goal: Duration(minutes: goalMinutes),
      tracked: stats.totalTracked,
    );
  });
});
