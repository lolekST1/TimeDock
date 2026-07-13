import '../entities/time_session.dart';

/// A fragment of a session falling within a single local calendar day.
///
/// Sessions are stored as one record even when they cross midnight; the day
/// timeline and daily reports render them as slices produced here. Slice
/// boundaries are exact UTC instants, so the slice durations of a session
/// always sum to its total duration — weekly and monthly totals can never
/// disagree with the daily view.
class SessionSlice {
  const SessionSlice({
    required this.session,
    required this.localDay,
    required this.startUtc,
    required this.endUtc,
    required this.offsetMinutes,
  });

  final TimeSession session;

  /// Date key of the local day this slice belongs to, as `DateTime.utc(y,m,d)`.
  final DateTime localDay;

  final DateTime startUtc;
  final DateTime endUtc;

  /// UTC offset used to render this slice's wall-clock times.
  final int offsetMinutes;

  Duration get duration => endUtc.difference(startUtc);

  DateTime get startLocal => startUtc.add(Duration(minutes: offsetMinutes));

  DateTime get endLocal => endUtc.add(Duration(minutes: offsetMinutes));
}

abstract final class TimeRules {
  /// Date key (`DateTime.utc(y,m,d)`) of the local day containing [utc]
  /// at the given UTC offset.
  static DateTime localDayKey(DateTime utc, int offsetMinutes) {
    final local = utc.add(Duration(minutes: offsetMinutes));
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Splits a session at local midnight boundaries.
  ///
  /// For a running session pass [nowUtc] (and optionally [nowOffsetMinutes],
  /// defaulting to the session's start offset) to slice up to "now".
  ///
  /// When the UTC offset changed mid-session (DST), midnight boundaries are
  /// computed with the start offset — a boundary may be off by the DST delta,
  /// but every boundary is an exact UTC instant, so the total is preserved.
  static List<SessionSlice> splitByLocalDay(
    TimeSession session, {
    DateTime? nowUtc,
    int? nowOffsetMinutes,
  }) {
    final startUtc = session.startUtc;
    final endUtc = session.endUtc ?? nowUtc;
    if (endUtc == null) {
      throw ArgumentError('running session requires nowUtc');
    }
    if (!endUtc.isAfter(startUtc)) {
      return const [];
    }
    final startOffset = session.startOffsetMinutes;
    final endOffset = session.endOffsetMinutes ??
        nowOffsetMinutes ??
        session.startOffsetMinutes;

    final slices = <SessionSlice>[];
    var cursorUtc = startUtc;
    var cursorDay = localDayKey(cursorUtc, startOffset);
    final lastDay = localDayKey(endUtc, endOffset);

    while (cursorDay.isBefore(lastDay)) {
      // Local midnight ending [cursorDay], converted to UTC with the start
      // offset (see doc comment for the DST caveat).
      final nextMidnightUtc = cursorDay
          .add(const Duration(days: 1))
          .subtract(Duration(minutes: startOffset));
      if (!nextMidnightUtc.isAfter(cursorUtc)) {
        // Offset math degenerated (extreme offset change); emit the remainder
        // as a single slice rather than looping forever.
        break;
      }
      final boundary =
          nextMidnightUtc.isBefore(endUtc) ? nextMidnightUtc : endUtc;
      slices.add(SessionSlice(
        session: session,
        localDay: cursorDay,
        startUtc: cursorUtc,
        endUtc: boundary,
        offsetMinutes: startOffset,
      ));
      if (!boundary.isBefore(endUtc)) {
        return slices;
      }
      cursorUtc = boundary;
      cursorDay = cursorDay.add(const Duration(days: 1));
    }

    slices.add(SessionSlice(
      session: session,
      localDay: lastDay,
      startUtc: cursorUtc,
      endUtc: endUtc,
      offsetMinutes: slices.isEmpty ? startOffset : endOffset,
    ));
    return slices;
  }

  /// Portion of a session's duration falling within the inclusive local-day
  /// range [firstDay]..[lastDay] (date keys as `DateTime.utc(y,m,d)`).
  static Duration durationInDayRange(
    TimeSession session,
    DateTime firstDay,
    DateTime lastDay, {
    DateTime? nowUtc,
    int? nowOffsetMinutes,
  }) {
    var total = Duration.zero;
    for (final slice in splitByLocalDay(session,
        nowUtc: nowUtc, nowOffsetMinutes: nowOffsetMinutes)) {
      if (!slice.localDay.isBefore(firstDay) &&
          !slice.localDay.isAfter(lastDay)) {
        total += slice.duration;
      }
    }
    return total;
  }
}
