import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/session_editing.dart';

import '../helpers.dart';

void main() {
  final start = DateTime.utc(2026, 7, 10, 8);
  final now = DateTime.utc(2026, 7, 10, 20);

  test('split divides a session at the given instant', () {
    final s = session(
      id: 'orig',
      start: start,
      end: start.add(const Duration(hours: 3)),
      comment: 'work',
    );
    final (first, second) = SessionEditing.split(
      s,
      atUtc: start.add(const Duration(hours: 1)),
      newId: 'new',
      atOffsetMinutes: 0,
      nowUtc: now,
    );

    expect(first.id, 'orig');
    expect(first.endUtc, start.add(const Duration(hours: 1)));
    expect(first.comment, 'work'); // original keeps its comment
    expect(first.wasEdited, isTrue);

    expect(second.id, 'new');
    expect(second.startUtc, start.add(const Duration(hours: 1)));
    expect(second.endUtc, start.add(const Duration(hours: 3)));
    expect(second.comment, isNull);
    expect(second.projectId, s.projectId);

    // The two halves exactly reconstruct the original span.
    expect(first.duration + second.duration, const Duration(hours: 3));
  });

  test('split rejects a point outside the session', () {
    final s = session(start: start, end: start.add(const Duration(hours: 1)));
    expect(
      () => SessionEditing.split(s,
          atUtc: start.add(const Duration(hours: 2)),
          newId: 'x',
          atOffsetMinutes: 0,
          nowUtc: now),
      throwsArgumentError,
    );
  });

  test('split rejects a running session', () {
    final s = session(start: start, end: null);
    expect(
      () => SessionEditing.split(s,
          atUtc: start.add(const Duration(minutes: 30)),
          newId: 'x',
          atOffsetMinutes: 0,
          nowUtc: now),
      throwsArgumentError,
    );
  });
}
