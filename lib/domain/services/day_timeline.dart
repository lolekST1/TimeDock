import '../entities/time_session.dart';
import 'time_rules.dart';

/// An entry on the day timeline: either a session slice or an untracked gap
/// between two slices.
sealed class TimelineEntry {
  const TimelineEntry({required this.startLocal, required this.endLocal});

  final DateTime startLocal;
  final DateTime endLocal;

  Duration get duration => endLocal.difference(startLocal);
}

class SessionBlock extends TimelineEntry {
  const SessionBlock({
    required this.slice,
    required super.startLocal,
    required super.endLocal,
  });

  final SessionSlice slice;

  TimeSession get session => slice.session;
}

/// Untracked time between two sessions — surfaced now so the "untracked time"
/// statistic (§12) is a pure read over this same structure later.
class GapBlock extends TimelineEntry {
  const GapBlock({required super.startLocal, required super.endLocal});
}

abstract final class DayTimeline {
  /// Builds the ordered timeline for [localDay] (a `DateTime.utc(y,m,d)` key)
  /// from [sessions], splitting midnight-crossing sessions and inserting gap
  /// blocks between non-adjacent slices. A running session is included when
  /// [nowUtc] is supplied.
  static List<TimelineEntry> build(
    DateTime localDay,
    Iterable<TimeSession> sessions, {
    DateTime? nowUtc,
    int? nowOffsetMinutes,
    bool includeGaps = true,
  }) {
    final slices = <SessionSlice>[];
    for (final session in sessions) {
      if (session.isRunning && nowUtc == null) continue;
      for (final slice in TimeRules.splitByLocalDay(session,
          nowUtc: nowUtc, nowOffsetMinutes: nowOffsetMinutes)) {
        if (slice.localDay == localDay) slices.add(slice);
      }
    }
    slices.sort((a, b) => a.startUtc.compareTo(b.startUtc));

    final entries = <TimelineEntry>[];
    SessionSlice? previous;
    for (final slice in slices) {
      if (includeGaps &&
          previous != null &&
          slice.startUtc.isAfter(previous.endUtc)) {
        entries.add(GapBlock(
          startLocal: previous.endLocal,
          endLocal: slice.startLocal,
        ));
      }
      entries.add(SessionBlock(
        slice: slice,
        startLocal: slice.startLocal,
        endLocal: slice.endLocal,
      ));
      // Only extend the "previous" cursor forward, so a fully-contained slice
      // never creates a negative gap.
      if (previous == null || slice.endUtc.isAfter(previous.endUtc)) {
        previous = slice;
      }
    }
    return entries;
  }

  static Duration trackedTotal(List<TimelineEntry> entries) =>
      entries.whereType<SessionBlock>().fold(
            Duration.zero,
            (sum, block) => sum + block.duration,
          );
}
