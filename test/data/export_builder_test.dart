import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/export_builder.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_session_repository.dart';
import 'package:timedock/data/repositories/drift_sub_project_repository.dart';
import 'package:timedock/data/repositories/drift_task_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/sub_project.dart';
import 'package:timedock/domain/entities/task.dart';
import 'package:timedock/domain/entities/time_session.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/domain/services/report_range.dart';

import '../helpers.dart';

void main() {
  late TimeDockDatabase db;
  late ExportBuilder builder;

  // Use local wall-clock times so range membership matches the export.
  final day = DateTime(2026, 7, 10, 8);
  final range = ReportRangeCalculator.rangeFor(
      ReportPeriod.day, DateTime.utc(2026, 7, 10));

  setUp(() async {
    db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    final wsRepo = DriftWorkspaceRepository(db);
    final pRepo = DriftProjectRepository(db);
    final spRepo = DriftSubProjectRepository(db);
    final tRepo = DriftTaskRepository(db);
    final sRepo = DriftSessionRepository(db);
    builder = ExportBuilder(
      workspaces: wsRepo,
      projects: pRepo,
      subProjects: spRepo,
      tasks: tRepo,
      sessions: sRepo,
    );

    final now = day.toUtc();
    await wsRepo.upsert(Workspace(id: 'w1', name: 'Praca', colorSeed: 0, createdAt: now, updatedAt: now));
    await pRepo.upsert(Project(id: 'p1', workspaceId: 'w1', name: 'Projekt2', color: 0, createdAt: now, updatedAt: now));
    await spRepo.upsert(SubProject(id: 'sp1', projectId: 'p1', name: 'Podprojekt1', createdAt: now, updatedAt: now));
    await tRepo.upsert(Task(id: 't1', projectId: 'p1', subProjectId: 'sp1', name: 'TASK-123', jiraId: 'TASK-123', createdAt: now, updatedAt: now));

    TimeSession sessionOf(String id, DateTime start, Duration d,
            {String? taskId, String? subId}) =>
        session(
          id: id,
          projectId: 'p1',
          subProjectId: subId,
          taskId: taskId,
          start: start.toUtc(),
          end: start.add(d).toUtc(),
          startOffset: start.timeZoneOffset.inMinutes,
          endOffset: start.timeZoneOffset.inMinutes,
        );

    await sRepo.upsert(sessionOf('s1', day, const Duration(hours: 2), taskId: 't1', subId: 'sp1'));
    await sRepo.upsert(sessionOf('s2', day.add(const Duration(hours: 3)), const Duration(hours: 1), subId: 'sp1'));
  });

  tearDown(() => db.close());

  test('per-session rows resolve names and Jira id', () async {
    final rows = await builder.perSessionRows('w1', range);
    expect(rows, hasLength(2));
    expect(rows.first.workspace, 'Praca');
    expect(rows.first.project, 'Projekt2');
    expect(rows.first.subProject, 'Podprojekt1');
    expect(rows.first.task, 'TASK-123');
    expect(rows.first.jiraId, 'TASK-123');
    expect(rows.first.duration, const Duration(hours: 2));
  });

  test('aggregate rows sum per task and label the untasked group', () async {
    final rows = await builder.aggregateRows('w1', range);
    final tasked = rows.firstWhere((r) => r.task == 'TASK-123');
    expect(tasked.total, const Duration(hours: 2));
    expect(tasked.sessionCount, 1);
    final untasked = rows.firstWhere((r) => r.task == '(bez zadania)');
    expect(untasked.total, const Duration(hours: 1));
  });
}
