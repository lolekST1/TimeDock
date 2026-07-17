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
          session(id: '1', taskId: 'PROJ-1234', start: at(8), end: at(9)),
          session(id: '2', taskId: 'PROJ-1234', start: at(10), end: at(11, 30)),
          session(id: '3', taskId: 'PROJ-1234', start: at(14), end: at(14, 45)),
        ],
        firstDay: day,
        lastDay: day,
      );
      final task = tree.projects.single.tasks.single;
      expect(task.taskId, 'PROJ-1234');
      expect(task.total, const Duration(hours: 3, minutes: 15));
      expect(task.entries, hasLength(3));
      expect(tree.total, const Duration(hours: 3, minutes: 15));
    });

    test('builds the project → sub-project → task hierarchy with sums', () {
      final tree = SessionAggregator.aggregate(
        sessions: [
          session(
              id: '1',
              projectId: 'p1',
              subProjectId: 'sp1',
              taskId: 'TASK-123',
              start: at(8),
              end: at(10)),
          session(
              id: '2',
              projectId: 'p1',
              subProjectId: 'sp1',
              taskId: 'TASK-555',
              start: at(10),
              end: at(13)),
          session(
              id: '3',
              projectId: 'p1',
              subProjectId: 'sp2',
              start: at(13),
              end: at(14)),
          session(id: '4', projectId: 'p2', start: at(14), end: at(15)),
        ],
        firstDay: day,
        lastDay: day,
      );

      expect(tree.total, const Duration(hours: 7));
      expect(tree.projects, hasLength(2));
      // Sorted by total, largest first.
      final project1 = tree.projects.first;
      expect(project1.projectId, 'p1');
      expect(project1.total, const Duration(hours: 6));

      final sub1 = project1.subProjects.first;
      expect(sub1.subProjectId, 'sp1');
      expect(sub1.total, const Duration(hours: 5));
      // Tasks sorted by total desc.
      expect(sub1.tasks.map((t) => t.taskId), ['TASK-555', 'TASK-123']);

      final sub2 = project1.subProjects[1];
      expect(sub2.tasks.single.taskId, isNull); // "(bez zadania)"
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
