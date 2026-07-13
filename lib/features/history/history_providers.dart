import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/session_editor.dart';
import '../../domain/services/day_timeline.dart';

final sessionEditorProvider = Provider<SessionEditor>(
    (ref) => SessionEditor(ref.watch(sessionRepositoryProvider)));

/// Identifies the timeline to show: a workspace and a local day
/// (`DateTime.utc(y, m, d)`).
class DayKey {
  const DayKey(this.workspaceId, this.localDay);

  final String workspaceId;
  final DateTime localDay;

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      other.workspaceId == workspaceId &&
      other.localDay == localDay;

  @override
  int get hashCode => Object.hash(workspaceId, localDay);
}

/// The ordered timeline (session blocks + gaps) for a given day, live-updating
/// as sessions change. Includes the running session using the current time.
final dayTimelineProvider =
    StreamProvider.family<List<TimelineEntry>, DayKey>((ref, key) {
  // Widen the query window by a day on each side so midnight-crossing
  // neighbours are captured; DayTimeline filters to the exact local day.
  final from = key.localDay.subtract(const Duration(days: 1));
  final to = key.localDay.add(const Duration(days: 2));
  return ref
      .watch(sessionRepositoryProvider)
      .watchOverlappingRange(key.workspaceId, from, to)
      .map((sessions) {
    final now = DateTime.now().toUtc();
    return DayTimeline.build(
      key.localDay,
      sessions,
      nowUtc: now,
      nowOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  });
});
