/// Report period and its local-day range. Days are `DateTime.utc(y, m, d)`
/// keys (matching [TimeRules.localDayKey]); the range is inclusive.
///
/// [custom] carries no fixed shape — its range is chosen by the user and held
/// outside the calculator, so [ReportRangeCalculator.rangeFor] must not be
/// called with it.
enum ReportPeriod { day, week, month, custom }

class ReportRange {
  const ReportRange({required this.firstDay, required this.lastDay});

  final DateTime firstDay;
  final DateTime lastDay;

  bool contains(DateTime day) =>
      !day.isBefore(firstDay) && !day.isAfter(lastDay);
}

abstract final class ReportRangeCalculator {
  /// The inclusive local-day range of the [period] containing [anchorDay].
  /// Weeks start on Monday.
  static ReportRange rangeFor(ReportPeriod period, DateTime anchorDay) {
    final day = DateTime.utc(anchorDay.year, anchorDay.month, anchorDay.day);
    switch (period) {
      case ReportPeriod.day:
        return ReportRange(firstDay: day, lastDay: day);
      case ReportPeriod.week:
        // DateTime.weekday: Monday = 1 … Sunday = 7.
        final first = day.subtract(Duration(days: day.weekday - 1));
        return ReportRange(
            firstDay: first, lastDay: first.add(const Duration(days: 6)));
      case ReportPeriod.month:
        final first = DateTime.utc(day.year, day.month, 1);
        // Day 0 of next month = last day of this month.
        final last = DateTime.utc(day.year, day.month + 1, 0);
        return ReportRange(firstDay: first, lastDay: last);
      case ReportPeriod.custom:
        throw ArgumentError('custom period has no calculated range');
    }
  }

  /// Moves the anchor by one whole period in [direction] (-1 or +1).
  static DateTime shift(
    ReportPeriod period,
    DateTime anchorDay,
    int direction,
  ) {
    final day = DateTime.utc(anchorDay.year, anchorDay.month, anchorDay.day);
    switch (period) {
      case ReportPeriod.day:
        return day.add(Duration(days: direction));
      case ReportPeriod.week:
        return day.add(Duration(days: 7 * direction));
      case ReportPeriod.month:
        return DateTime.utc(day.year, day.month + direction, day.day);
      case ReportPeriod.custom:
        return day; // custom ranges are shifted by their length, see provider
    }
  }

  /// Shifts a custom [range] by its own length in [direction] (-1 or +1), so
  /// the prev/next buttons page through adjacent windows of the same size.
  static ReportRange shiftCustom(ReportRange range, int direction) {
    final lengthDays = range.lastDay.difference(range.firstDay).inDays + 1;
    final delta = Duration(days: lengthDays * direction);
    return ReportRange(
      firstDay: range.firstDay.add(delta),
      lastDay: range.lastDay.add(delta),
    );
  }
}
