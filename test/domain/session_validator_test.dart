import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/session_validator.dart';

import '../helpers.dart';

void main() {
  final base = DateTime.utc(2026, 7, 10);
  DateTime at(int hour, [int minute = 0]) =>
      base.add(Duration(hours: hour, minutes: minute));

  group('SessionValidator', () {
    test('rejects start not before end', () {
      final result = SessionValidator.validate(
        candidate: session(start: at(10), end: at(9)),
        existing: const [],
      );
      expect(result.startBeforeEnd, isFalse);
      expect(result.isValid, isFalse);
    });

    test('accepts a session with no neighbours', () {
      final result = SessionValidator.validate(
        candidate: session(start: at(8), end: at(9)),
        existing: const [],
      );
      expect(result.isValid, isTrue);
    });

    test('back-to-back sessions do not conflict', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(9), end: at(10)),
        existing: [session(id: 'a', start: at(8), end: at(9))],
      );
      expect(result.conflicts, isEmpty);
      expect(result.isValid, isTrue);
    });

    test('ignores a stale copy of the candidate itself', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'same', start: at(8), end: at(10)),
        existing: [session(id: 'same', start: at(8), end: at(9))],
      );
      expect(result.isValid, isTrue);
    });

    test('neighbour overlapping at its end gets its end trimmed back', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(8, 30), end: at(10)),
        existing: [session(id: 'a', start: at(8), end: at(9))],
      );
      expect(result.conflicts.map((s) => s.id), ['a']);
      expect(result.isAutoResolvable, isTrue);
      final trimmed = result.proposedTrims.single;
      expect(trimmed.id, 'a');
      expect(trimmed.endUtc, at(8, 30));
      expect(trimmed.wasEdited, isTrue);
    });

    test('neighbour overlapping at its start gets pushed forward', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(8), end: at(9, 30)),
        existing: [session(id: 'b', start: at(9), end: at(11))],
      );
      final trimmed = result.proposedTrims.single;
      expect(trimmed.startUtc, at(9, 30));
      expect(trimmed.endUtc, at(11));
    });

    test('neighbour fully inside the candidate is unresolvable', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(8), end: at(12)),
        existing: [session(id: 'inner', start: at(9), end: at(10))],
      );
      expect(result.unresolvable.map((s) => s.id), ['inner']);
      expect(result.isAutoResolvable, isFalse);
    });

    test('neighbour fully containing the candidate is unresolvable', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(9), end: at(10)),
        existing: [session(id: 'outer', start: at(8), end: at(12))],
      );
      expect(result.unresolvable.map((s) => s.id), ['outer']);
    });

    test('running neighbour conflicts using now as its provisional end', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(8), end: at(10)),
        existing: [session(id: 'run', start: at(9), end: null)],
        nowUtc: at(11),
      );
      expect(result.conflicts.map((s) => s.id), ['run']);
    });

    test('multiple neighbours resolved independently', () {
      final result = SessionValidator.validate(
        candidate: session(id: 'new', start: at(8, 30), end: at(10, 30)),
        existing: [
          session(id: 'before', start: at(8), end: at(9)),
          session(id: 'after', start: at(10), end: at(11)),
        ],
      );
      expect(result.conflicts, hasLength(2));
      expect(result.isAutoResolvable, isTrue);
      expect(result.proposedTrims, hasLength(2));
    });
  });
}
