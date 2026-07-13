import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_session_repository.dart';
import 'package:timedock/data/repositories/drift_sub_project_repository.dart';
import 'package:timedock/data/repositories/drift_task_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/data/seed.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/task.dart';
import 'package:timedock/domain/entities/workspace.dart';

import '../helpers.dart';

void main() {
  late TimeDockDatabase db;
  late DriftWorkspaceRepository workspaces;
  late DriftProjectRepository projects;
  late DriftSubProjectRepository subProjects;
  late DriftTaskRepository tasks;
  late DriftSessionRepository sessions;

  final now = DateTime.utc(2026, 7, 10, 8);

  Workspace workspace([String id = 'w1']) => Workspace(
      id: id, name: id, colorSeed: 0xFF000000, createdAt: now, updatedAt: now);

  Project project(String id, {String workspaceId = 'w1'}) => Project(
      id: id,
      workspaceId: workspaceId,
      name: id,
      color: 0xFF112233,
      createdAt: now,
      updatedAt: now);

  setUp(() {
    db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    workspaces = DriftWorkspaceRepository(db);
    projects = DriftProjectRepository(db);
    subProjects = DriftSubProjectRepository(db);
    tasks = DriftTaskRepository(db);
    sessions = DriftSessionRepository(db);
  });

  tearDown(() => db.close());

  group('seeding', () {
    DatabaseSeeder seeder() => DatabaseSeeder(
        workspaces: workspaces,
        projects: projects,
        subProjects: subProjects,
        nowUtc: () => now);

    test('creates workspaces, projects and Carlsberg sub-projects', () async {
      await seeder().seedIfEmpty();

      final ws = await workspaces.watchAll().first;
      expect(ws.map((w) => w.name), ['Absysco', 'Prywatne']);

      final absysco = ws.first;
      final absyscoProjects =
          await projects.watchByWorkspace(absysco.id).first;
      expect(absyscoProjects, hasLength(9));
      expect(absyscoProjects.first.name, 'Danone');

      final carlsberg =
          absyscoProjects.singleWhere((p) => p.name == 'Carlsberg');
      final subs = await subProjects.watchByProject(carlsberg.id).first;
      expect(subs.map((s) => s.name), ['TT', 'LF', 'CC', 'Dyskonty']);
    });

    test('is idempotent — second run adds nothing', () async {
      await seeder().seedIfEmpty();
      await seeder().seedIfEmpty();
      final ws = await workspaces.watchAll().first;
      expect(ws, hasLength(2));
    });
  });

  group('sessions', () {
    setUp(() async {
      await workspaces.upsert(workspace());
      await projects.upsert(project('p1'));
      await projects.upsert(project('p2'));
    });

    test('watchActive reflects the single running session', () async {
      expect(await sessions.getActive(), isNull);
      await sessions.upsert(session(id: 'run', start: now, end: null));
      final active = await sessions.getActive();
      expect(active!.id, 'run');
      expect(active.isRunning, isTrue);

      await sessions
          .upsert(session(id: 'run', start: now, end: now.add(const Duration(hours: 1))));
      expect(await sessions.getActive(), isNull);
    });

    test('listOverlappingRange returns sessions crossing the window', () async {
      await sessions.upsert(session(
          id: 'a',
          start: now,
          end: now.add(const Duration(hours: 1))));
      await sessions.upsert(session(
          id: 'b',
          start: now.add(const Duration(hours: 5)),
          end: now.add(const Duration(hours: 6))));

      final hit = await sessions.listOverlappingRange(
          'w1', now.add(const Duration(minutes: 30)), now.add(const Duration(hours: 2)));
      expect(hit.map((s) => s.id), ['a']);
    });

    test('recent contexts are deduplicated, newest first', () async {
      await tasks.upsert(Task(
          id: 'DAN-1',
          projectId: 'p1',
          name: 'DAN-1',
          createdAt: now,
          updatedAt: now));
      Future<void> log(String id, String projectId, String? taskId,
          int hoursAgo) async {
        final start = now.subtract(Duration(hours: hoursAgo));
        await sessions.upsert(session(
            id: id,
            projectId: projectId,
            taskId: taskId,
            start: start,
            end: start.add(const Duration(minutes: 30))));
      }

      await log('1', 'p1', 'DAN-1', 5);
      await log('2', 'p2', null, 3);
      await log('3', 'p1', 'DAN-1', 1); // same context as '1'

      final recents = await sessions.watchRecentContexts('w1').first;
      expect(recents, hasLength(2));
      expect(recents[0].projectId, 'p1');
      expect(recents[0].taskId, 'DAN-1');
      expect(recents[1].projectId, 'p2');
    });

    test('anyForProject reflects logged sessions', () async {
      expect(await sessions.anyForProject('p1'), isFalse);
      await sessions.upsert(session(
          id: 'a', start: now, end: now.add(const Duration(hours: 1))));
      expect(await sessions.anyForProject('p1'), isTrue);
      expect(await sessions.anyForProject('p2'), isFalse);
    });
  });

  group('delete guards', () {
    setUp(() async {
      await workspaces.upsert(workspace());
      await projects.upsert(project('p1'));
    });

    test('project with sessions cannot be deleted', () async {
      await sessions.upsert(session(
          id: 'a', start: now, end: now.add(const Duration(hours: 1))));
      expect(() => projects.delete('p1'), throwsStateError);
    });

    test('project without sessions is deleted', () async {
      await projects.delete('p1');
      expect(await projects.getById('p1'), isNull);
    });
  });
}
