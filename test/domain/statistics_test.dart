import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/statistics.dart';

import '../helpers.dart';

void main() {
  final day = DateTime.utc(2026, 7, 10);
  final nextDay = DateTime.utc(2026, 7, 11);
  DateTime at(int h, [int m = 0]) => day.add(Duration(hours: h, minutes: m));

  test('empty input yields empty stats', () {
    final stats = StatisticsCalculator.compute(
        sessions: const [], firstDay: day, lastDay: day);
    expect(stats, SessionStats.empty);
  });

  test('totals, longest and average over finished sessions', () {
    final stats = StatisticsCalculator.compute(
      sessions: [
        session(id: '1', start: at(8), end: at(9)), // 1h
        session(id: '2', start: at(10), end: at(12)), // 2h
      ],
      firstDay: day,
      lastDay: day,
    );
    expect(stats.sessionCount, 2);
    expect(stats.totalTracked, const Duration(hours: 3));
    expect(stats.longestSession, const Duration(hours: 2));
    expect(stats.averageSession, const Duration(minutes: 90));
  });

  test('ignores running sessions and out-of-range days', () {
    final stats = StatisticsCalculator.compute(
      sessions: [
        session(id: 'run', start: at(8), end: null),
        session(id: 'today', start: at(9), end: at(10)),
        session(
            id: 'tomorrow',
            start: nextDay.add(const Duration(hours: 9)),
            end: nextDay.add(const Duration(hours: 10))),
      ],
      firstDay: day,
      lastDay: day,
    );
    expect(stats.sessionCount, 1);
    expect(stats.totalTracked, const Duration(hours: 1));
  });

  test('counts project switches between consecutive sessions', () {
    final stats = StatisticsCalculator.compute(
      sessions: [
        session(id: '1', projectId: 'a', start: at(8), end: at(9)),
        session(id: '2', projectId: 'a', start: at(9), end: at(10)),
        session(id: '3', projectId: 'b', start: at(10), end: at(11)),
        session(id: '4', projectId: 'a', start: at(11), end: at(12)),
      ],
      firstDay: day,
      lastDay: day,
    );
    // a→a (no), a→b (switch), b→a (switch) = 2.
    expect(stats.projectSwitches, 2);
  });

  test('untracked time is the gaps between sessions in the day', () {
    final stats = StatisticsCalculator.compute(
      sessions: [
        session(id: '1', start: at(8), end: at(9)),
        session(id: '2', start: at(11), end: at(12)), // 2h gap
      ],
      firstDay: day,
      lastDay: day,
    );
    expect(stats.untracked, const Duration(hours: 2));
  });

  test('focus score is the share of tracked time in sessions >= 25 min', () {
    final stats = StatisticsCalculator.compute(
      sessions: [
        session(id: 'long', start: at(8), end: at(9)), // 60 min, focused
        session(id: 'short', start: at(9), end: at(9, 20)), // 20 min, not
      ],
      firstDay: day,
      lastDay: day,
    );
    // 60 of 80 minutes are focused → 75.
    expect(stats.focusScore, 75);
  });

  test('focus score is 100 when all sessions are long', () {
    final stats = StatisticsCalculator.compute(
      sessions: [session(id: '1', start: at(8), end: at(9))],
      firstDay: day,
      lastDay: day,
    );
    expect(stats.focusScore, 100);
  });
}
