import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/day_timeline.dart';

import '../helpers.dart';

void main() {
  final day = DateTime.utc(2026, 7, 10);
  DateTime at(int hour, [int minute = 0]) =>
      day.add(Duration(hours: hour, minutes: minute));

  test('orders sessions and inserts gaps between them', () {
    final entries = DayTimeline.build(day, [
      session(id: 'b', start: at(11), end: at(11, 45)),
      session(id: 'a', start: at(8), end: at(9, 10)),
    ]);

    expect(entries, hasLength(3));
    expect(entries[0], isA<SessionBlock>());
    expect((entries[0] as SessionBlock).session.id, 'a');
    expect(entries[1], isA<GapBlock>());
    expect(entries[1].duration, const Duration(hours: 1, minutes: 50));
    expect((entries[2] as SessionBlock).session.id, 'b');
  });

  test('adjacent sessions produce no gap', () {
    final entries = DayTimeline.build(day, [
      session(id: 'a', start: at(8), end: at(9)),
      session(id: 'b', start: at(9), end: at(10)),
    ]);
    expect(entries.whereType<GapBlock>(), isEmpty);
    expect(entries, hasLength(2));
  });

  test('gaps can be disabled', () {
    final entries = DayTimeline.build(
      day,
      [
        session(id: 'a', start: at(8), end: at(9)),
        session(id: 'b', start: at(11), end: at(12)),
      ],
      includeGaps: false,
    );
    expect(entries.whereType<GapBlock>(), isEmpty);
    expect(entries, hasLength(2));
  });

  test('midnight-crossing session appears on both days', () {
    // 23:00–01:00 local at +120 = 21:00–23:00 UTC.
    final s = session(
        id: 'night', start: at(21), end: at(23), startOffset: 120);
    final firstDay = DayTimeline.build(day, [s]);
    final nextDay = DayTimeline.build(DateTime.utc(2026, 7, 11), [s]);
    expect(firstDay.whereType<SessionBlock>().single.duration,
        const Duration(hours: 1));
    expect(nextDay.whereType<SessionBlock>().single.duration,
        const Duration(hours: 1));
  });

  test('running session appears only when now is provided', () {
    final s = session(id: 'run', start: at(8), end: null);
    expect(DayTimeline.build(day, [s]), isEmpty);
    final withNow = DayTimeline.build(day, [s], nowUtc: at(9));
    expect(withNow.whereType<SessionBlock>().single.duration,
        const Duration(hours: 1));
  });

  test('trackedTotal sums only session blocks', () {
    final entries = DayTimeline.build(day, [
      session(id: 'a', start: at(8), end: at(9)),
      session(id: 'b', start: at(11), end: at(12)),
    ]);
    expect(DayTimeline.trackedTotal(entries), const Duration(hours: 2));
  });
}
