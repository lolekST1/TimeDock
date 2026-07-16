import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/export_builder.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_session_repository.dart';
import 'package:timedock/data/repositories/drift_task_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/task.dart';
import 'package:timedock/domain/entities/time_session.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/domain/services/report_range.dart';

import '../helpers.dart';

void main() {
  late TimeDockDatabase db;
  late DriftWorkspaceRepository wsRepo;
  late DriftProjectRepository pRepo;
  late DriftTaskRepository tRepo;
  late DriftSessionRepository sRepo;
  late WorklogExportBuilder builder;

  final day = DateTime(2026, 7, 10, 8);
  final range = ReportRangeCalculator.rangeFor(
      ReportPeriod.day, DateTime.utc(2026, 7, 10));

  // Re-stamps the workspace with the desired export flag (upsert replaces).
  Future<void> setExportFlag({required bool exports}) async {
    final now = day.toUtc();
    await wsRepo.upsert(Workspace(
      id: 'w1',
      name: 'Absysco',
      colorSeed: 0,
      exportsToTimesheet: exports,
      createdAt: now,
      updatedAt: now,
    ));
  }

  setUp(() async {
    db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    wsRepo = DriftWorkspaceRepository(db);
    pRepo = DriftProjectRepository(db);
    tRepo = DriftTaskRepository(db);
    sRepo = DriftSessionRepository(db);
    builder = WorklogExportBuilder(
      workspaces: wsRepo,
      projects: pRepo,
      tasks: tRepo,
      sessions: sRepo,
    );

    final now = day.toUtc();
    // The workspace must exist before its project (FK); tests re-stamp its flag.
    await setExportFlag(exports: false);
    await pRepo.upsert(Project(
        id: 'p1', workspaceId: 'w1', name: 'Danone', color: 0,
        createdAt: now, updatedAt: now));
    // t1: has a Jira id. t2: no Jira id (should be skipped).
    await tRepo.upsert(Task(
        id: 't1', projectId: 'p1', name: 'Feature', jiraId: 'ABS-123',
        createdAt: now, updatedAt: now));
    await tRepo.upsert(Task(
        id: 't2', projectId: 'p1', name: 'Bez Jiry',
        createdAt: now, updatedAt: now));

    TimeSession finished(String id, DateTime start, Duration d,
            {String? taskId, String? comment}) =>
        session(
          id: id,
          projectId: 'p1',
          taskId: taskId,
          comment: comment,
          start: start.toUtc(),
          end: start.add(d).toUtc(),
          startOffset: start.timeZoneOffset.inMinutes,
          endOffset: start.timeZoneOffset.inMinutes,
        );

    // s1: finished, task with Jira → exported.
    await sRepo.upsert(finished('s1', day, const Duration(hours: 2),
        taskId: 't1', comment: 'Analiza'));
    // s2: finished, task without Jira → skipped.
    await sRepo.upsert(finished('s2', day.add(const Duration(hours: 3)),
        const Duration(hours: 1), taskId: 't2'));
    // s3: finished, no task at all → skipped.
    await sRepo.upsert(finished('s3', day.add(const Duration(hours: 5)),
        const Duration(minutes: 30)));
    // s4: running (no end) → skipped even though its task has a Jira id.
    await sRepo.upsert(session(
      id: 's4',
      projectId: 'p1',
      taskId: 't1',
      start: day.add(const Duration(hours: 6)).toUtc(),
      startOffset: day.timeZoneOffset.inMinutes,
    ));
  });

  tearDown(() => db.close());

  test('exports only finished, jira-tagged sessions when workspace opts in',
      () async {
    await setExportFlag(exports: true);
    final rows = (await builder.worklogExport('w1', range)).rows;
    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.sessionId, 's1');
    expect(r.issueKey, 'ABS-123');
    expect(r.durationSeconds, const Duration(hours: 2).inSeconds);
    expect(r.description, 'Analiza');
    expect(r.workspace, 'Absysco');
  });

  test('counts finished in-range sessions skipped for a missing Jira id',
      () async {
    await setExportFlag(exports: true);
    // s2 (task without Jira) and s3 (no task) are skipped; s4 is running.
    final result = await builder.worklogExport('w1', range);
    expect(result.skippedNoJira, 2);
  });

  test('exports nothing when the workspace is not flagged for export',
      () async {
    await setExportFlag(exports: false);
    final result = await builder.worklogExport('w1', range);
    expect(result.rows, isEmpty);
    expect(result.skippedNoJira, 0); // nothing scanned when opted out
  });

  test('stamps the configured author onto every row', () async {
    await setExportFlag(exports: true);
    final rows = (await builder.worklogExport('w1', range,
            author: '  jan@absysco.com  '))
        .rows;
    expect(rows, hasLength(1));
    expect(rows.single.author, 'jan@absysco.com'); // trimmed
  });

  test('a blank author is normalised to null', () async {
    await setExportFlag(exports: true);
    for (final author in [null, '', '   ']) {
      final rows = (await builder.worklogExport('w1', range, author: author)).rows;
      expect(rows.single.author, isNull);
    }
  });

  group('shouldExport rule', () {
    final finished = session(
      start: day.toUtc(),
      end: day.add(const Duration(hours: 1)).toUtc(),
    );
    final running = session(start: day.toUtc());

    test('true only for a finished, jira-tagged session in an opted-in ws', () {
      expect(
          WorklogExportBuilder.shouldExport(finished,
              workspaceExports: true, jiraId: 'ABS-1'),
          isTrue);
    });

    test('false when the workspace has not opted in', () {
      expect(
          WorklogExportBuilder.shouldExport(finished,
              workspaceExports: false, jiraId: 'ABS-1'),
          isFalse);
    });

    test('false for a running session', () {
      expect(
          WorklogExportBuilder.shouldExport(running,
              workspaceExports: true, jiraId: 'ABS-1'),
          isFalse);
    });

    test('false when the jira id is null, empty or blank', () {
      for (final jira in [null, '', '   ']) {
        expect(
            WorklogExportBuilder.shouldExport(finished,
                workspaceExports: true, jiraId: jira),
            isFalse);
      }
    });
  });
}
