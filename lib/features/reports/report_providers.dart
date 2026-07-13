import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/services/report_range.dart';
import '../../domain/services/session_aggregator.dart';
import '../app_state/app_providers.dart';

final reportPeriodProvider = StateProvider<ReportPeriod>(
    (ref) => ReportPeriod.week);

/// Local-day anchor (`DateTime.utc(y, m, d)`) whose period is shown.
final reportAnchorProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
});

/// The user-chosen range when [reportPeriodProvider] is [ReportPeriod.custom].
/// Defaults to the current week until the user picks a range.
final customRangeProvider = StateProvider<ReportRange>((ref) {
  final now = DateTime.now();
  return ReportRangeCalculator.rangeFor(
      ReportPeriod.week, DateTime.utc(now.year, now.month, now.day));
});

final reportRangeProvider = Provider<ReportRange>((ref) {
  final period = ref.watch(reportPeriodProvider);
  if (period == ReportPeriod.custom) {
    return ref.watch(customRangeProvider);
  }
  return ReportRangeCalculator.rangeFor(period, ref.watch(reportAnchorProvider));
});

/// The aggregated report tree for the selected workspace and period, live.
final reportTreeProvider = StreamProvider<ReportTree>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceProvider);
  if (workspaceId == null) {
    return Stream.value(ReportTree.empty);
  }
  final range = ref.watch(reportRangeProvider);
  // Widen the query so midnight-crossing sessions at the edges are included;
  // the aggregator clips durations to the exact day range.
  final from = range.firstDay.subtract(const Duration(days: 1));
  final to = range.lastDay.add(const Duration(days: 2));

  return ref
      .watch(sessionRepositoryProvider)
      .watchOverlappingRange(workspaceId, from, to)
      .map((sessions) {
    final now = DateTime.now().toUtc();
    return SessionAggregator.aggregate(
      sessions: sessions,
      firstDay: range.firstDay,
      lastDay: range.lastDay,
      nowUtc: now,
      nowOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  });
});
