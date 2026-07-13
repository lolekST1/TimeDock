import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/session_aggregator.dart';

import '../helpers.dart';

void main() {
  final day = DateTime.utc(2026, 7, 10);
  DateTime at(int hour, [int minute = 0]) =>
      day.add(Duration(hours: hour, minutes: minute));

  group('SessionAggregator', () {
    test('groups many sessions of one task into a single row', () {
      final tree = SessionAggregator.aggregate(
        sessions: [
          session(id: '1', taskId: 'DAN-1234', start: at(8), end: at(9)),
          session(id: '2', taskId: 'DAN-1234', start: at(10), end: at(11, 30)),
          session(id: '3', taskId: 'DAN-1234', start: at(14), end: at(14, 45)),
        ],
        firstDay: day,
        lastDay: day,
      );
      final task = tree.projects.single.tasks.single;
      expect(task.taskId, 'DAN-1234');
      expect(task.total, const Duration(hours: 3, minutes: 15));
      expect(task.entries, hasLength(3));
      expect(tree.total, const Duration(hours: 3, minutes: 15));
    });

    test('builds the project → sub-project → task hierarchy with sums', () {
      final tree = SessionAggregator.aggregate(
        sessions: [
          session(
              id: '1',
              projectId: 'carlsberg',
              subProjectId: 'tt',
              taskId: 'CAR-123',
              start: at(8),
              end: at(10)),
          session(
              id: '2',
              projectId: 'carlsberg',
              subProjectId: 'tt',
              taskId: 'CAR-555',
              start: at(10),
              end: at(13)),
          session(
              id: '3',
              projectId: 'carlsberg',
              subProjectId: 'lf',
              start: at(13),
              end: at(14)),
          session(id: '4', projectId: 'danone', start: at(14), end: at(15)),
        ],
        firstDay: day,
        lastDay: day,
      );

      expect(tree.total, const Duration(hours: 7));
      expect(tree.projects, hasLength(2));
      // Sorted by total, largest first.
      final carlsberg = tree.projects.first;
      expect(carlsberg.projectId, 'carlsberg');
      expect(carlsberg.total, const Duration(hours: 6));

      final tt = carlsberg.subProjects.first;
      expect(tt.subProjectId, 'tt');
      expect(tt.total, const Duration(hours: 5));
      // Tasks sorted by total desc.
      expect(tt.tasks.map((t) => t.taskId), ['CAR-555', 'CAR-123']);

      final lf = carlsberg.subProjects[1];
      expect(lf.tasks.single.taskId, isNull); // "(bez zadania)"
    });

    test('unassigned group sorts last regardless of size', () {
      final tree = SessionAggregator.aggregate(
        sessions: [
          session(id: '1', taskId: 'T-1', start: at(8), end: at(8, 30)),
          session(id: '2', start: at(9), end: at(15)),
        ],
        firstDay: day,
        lastDay: day,
      );
      final tasks = tree.projects.single.tasks;
      expect(tasks.map((t) => t.taskId), ['T-1', null]);
    });

    test('clips sessions crossing the range edge', () {
      // 21:00–23:00 UTC at +120 = 23:00–01:00 local, so only one hour
      // belongs to the requested day.
      final tree = SessionAggregator.aggregate(
        sessions: [
          session(
              id: '1',
              start: at(21),
              end: at(23),
              startOffset: 120),
        ],
        firstDay: day,
        lastDay: day,
      );
      expect(tree.total, const Duration(hours: 1));
    });

    test('running session included when now is provided', () {
      final tree = SessionAggregator.aggregate(
        sessions: [session(id: '1', start: at(8), end: null)],
        firstDay: day,
        lastDay: day,
        nowUtc: at(9, 15),
      );
      expect(tree.total, const Duration(hours: 1, minutes: 15));
    });

    test('running session skipped when now is not provided', () {
      final tree = SessionAggregator.aggregate(
        sessions: [session(id: '1', start: at(8), end: null)],
        firstDay: day,
        lastDay: day,
      );
      expect(tree.total, Duration.zero);
    });
  });
}
