import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
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
