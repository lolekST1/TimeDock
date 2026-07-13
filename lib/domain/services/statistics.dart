import '../entities/time_session.dart';
import 'day_timeline.dart';

/// Aggregate statistics over a period. Pure functions over sessions, so no
/// schema change is ever needed to add a metric (see §12 of the spec).
class SessionStats {
  const SessionStats({
    required this.totalTracked,
    required this.longestSession,
    required this.averageSession,
    required this.sessionCount,
    required this.projectSwitches,
    required this.untracked,
    required this.focusScore,
  });

  static const empty = SessionStats(
    totalTracked: Duration.zero,
    longestSession: Duration.zero,
    averageSession: Duration.zero,
    sessionCount: 0,
    projectSwitches: 0,
    untracked: Duration.zero,
    focusScore: 0,
  );

  final Duration totalTracked;
  final Duration longestSession;
  final Duration averageSession;
  final int sessionCount;

  /// How many times the project changed between consecutive sessions
  /// (chronological). Low is good — it means fewer context switches.
  final int projectSwitches;

  /// Time inside the working span of each day that was not tracked (the gaps
  /// between the first and last session of the day).
  final Duration untracked;

  /// 0–100: share of tracked time spent in focused sessions (at least
  /// [focusThreshold]). Simple and explainable — rewards long, uninterrupted
  /// blocks over fragmented ones.
  final int focusScore;
}

abstract final class StatisticsCalculator {
  /// A session must last at least this long to count as "focused".
  static const focusThreshold = Duration(minutes: 25);

  /// Computes statistics for the inclusive local-day range
  /// [firstDay]..[lastDay]. Only finished sessions whose local start day falls
  /// in the range are considered, using their full durations.
  static SessionStats compute({
    required Iterable<TimeSession> sessions,
    required DateTime firstDay,
    required DateTime lastDay,
  }) {
    final inRange = sessions.where((s) {
      if (s.isRunning) return false;
      final startLocal = s.startLocal;
      final day = DateTime.utc(startLocal.year, startLocal.month, startLocal.day);
      return !day.isBefore(firstDay) && !day.isAfter(lastDay);
    }).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    if (inRange.isEmpty) return SessionStats.empty;

    var total = Duration.zero;
    var longest = Duration.zero;
    var focusTracked = Duration.zero;
    var switches = 0;
    String? previousProject;

    for (final s in inRange) {
      final d = s.duration;
      total += d;
      if (d > longest) longest = d;
      if (d >= focusThreshold) focusTracked += d;
      if (previousProject != null && previousProject != s.projectId) {
        switches++;
      }
      previousProject = s.projectId;
    }

    final average = Duration(
        microseconds: (total.inMicroseconds / inRange.length).round());
    final focus = total == Duration.zero
        ? 0
        : (100 * focusTracked.inSeconds / total.inSeconds).round();

    return SessionStats(
      totalTracked: total,
      longestSession: longest,
      averageSession: average,
      sessionCount: inRange.length,
      projectSwitches: switches,
      untracked: _untracked(inRange, firstDay, lastDay),
      focusScore: focus,
    );
  }

  /// Sum of the gaps between sessions within each day of the range, using the
  /// same timeline logic the history screen shows.
  static Duration _untracked(
    List<TimeSession> sessions,
    DateTime firstDay,
    DateTime lastDay,
  ) {
    var untracked = Duration.zero;
    final days = lastDay.difference(firstDay).inDays;
    for (var i = 0; i <= days; i++) {
      final day = firstDay.add(Duration(days: i));
      final entries = DayTimeline.build(day, sessions);
      for (final entry in entries) {
        if (entry is GapBlock) untracked += entry.duration;
      }
    }
    return untracked;
  }
}
