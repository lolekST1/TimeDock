import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/backup_service.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_session_repository.dart';
import 'package:timedock/data/repositories/drift_sub_project_repository.dart';
import 'package:timedock/data/repositories/drift_task_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/sub_project.dart';
import 'package:timedock/domain/entities/task.dart';
import 'package:timedock/domain/entities/workspace.dart';

import '../helpers.dart';

void main() {
  final now = DateTime.utc(2026, 7, 10, 8);

  TimeDockDatabase freshDb() =>
      TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));

  Future<void> seed(TimeDockDatabase db) async {
    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'Praca', colorSeed: 0xFF1565C0, createdAt: now, updatedAt: now));
    await DriftProjectRepository(db).upsert(Project(
        id: 'p1', workspaceId: 'w1', name: 'Projekt2', color: 0xFF2E7D32, createdAt: now, updatedAt: now));
    await DriftSubProjectRepository(db).upsert(SubProject(
        id: 'sp1', projectId: 'p1', name: 'Podprojekt1', createdAt: now, updatedAt: now));
    await DriftTaskRepository(db).upsert(Task(
        id: 't1', projectId: 'p1', subProjectId: 'sp1', name: 'TASK-123', jiraId: 'TASK-123', createdAt: now, updatedAt: now));
    await DriftSessionRepository(db).upsert(session(
        id: 's1',
        projectId: 'p1',
        subProjectId: 'sp1',
        taskId: 't1',
        start: now,
        end: now.add(const Duration(hours: 2)),
        comment: 'praca, z przecinkiem'));
  }

  test('export then import into a fresh database reproduces all data', () async {
    final source = freshDb();
    await seed(source);
    final json = await BackupService(source).exportToJson();
    await source.close();

    final target = freshDb();
    addTearDown(target.close);
    await BackupService(target).importFromJson(json);

    final sessions = DriftSessionRepository(target);
    final projects = DriftProjectRepository(target);
    final subProjects = DriftSubProjectRepository(target);
    final tasks = DriftTaskRepository(target);

    expect((await projects.watchByWorkspace('w1').first).single.name,
        'Projekt2');
    expect((await subProjects.watchByProject('p1').first).single.name,
        'Podprojekt1');
    final task = (await tasks.watchByProject('p1').first).single;
    expect(task.jiraId, 'TASK-123');

    final restored = (await sessions.listOverlappingRange(
            'w1', now.subtract(const Duration(days: 1)), now.add(const Duration(days: 1))))
        .single;
    expect(restored.id, 's1');
    expect(restored.duration, const Duration(hours: 2));
    expect(restored.comment, 'praca, z przecinkiem');
    expect(restored.taskId, 't1');
  });

  test('import is idempotent (re-importing changes nothing)', () async {
    final db = freshDb();
    addTearDown(db.close);
    await seed(db);
    final backup = BackupService(db);
    final json = await backup.exportToJson();

    await backup.importFromJson(json);
    await backup.importFromJson(json);

    final projects = await DriftProjectRepository(db).watchByWorkspace('w1').first;
    expect(projects, hasLength(1));
  });

  test('rejects a newer format version', () async {
    final db = freshDb();
    addTearDown(db.close);
    expect(
      () => BackupService(db).importFromMap({'formatVersion': 999}),
      throwsA(isA<FormatException>()),
    );
  });

  test('export carries the format version', () async {
    final db = freshDb();
    addTearDown(db.close);
    final map = await BackupService(db).exportToMap();
    expect(map['formatVersion'], BackupService.formatVersion);
  });
}
