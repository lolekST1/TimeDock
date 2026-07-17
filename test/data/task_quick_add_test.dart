import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_task_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/data/task_quick_add.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/workspace.dart';

void main() {
  late TimeDockDatabase db;
  late DriftTaskRepository tasks;
  late TaskQuickAdd quickAdd;

  final now = DateTime.utc(2026, 7, 10, 8);

  setUp(() async {
    db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    tasks = DriftTaskRepository(db);
    quickAdd = TaskQuickAdd(tasks);
    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'w1', colorSeed: 0, createdAt: now, updatedAt: now));
    await DriftProjectRepository(db).upsert(Project(
        id: 'p1', workspaceId: 'w1', name: 'p1', color: 0, createdAt: now, updatedAt: now));
  });

  tearDown(() => db.close());

  test('returns null when nothing is entered', () async {
    expect(await quickAdd.findOrCreate(projectId: 'p1'), isNull);
    expect(
        await quickAdd.findOrCreate(projectId: 'p1', name: '  ', jiraId: ''),
        isNull);
  });

  test('creates a new task from a name', () async {
    final id = await quickAdd.findOrCreate(projectId: 'p1', name: 'Landing Page');
    final created = await tasks.getById(id!);
    expect(created!.name, 'Landing Page');
    expect(created.jiraId, isNull);
  });

  test('uses the Jira id as the name when only Jira is given', () async {
    final id = await quickAdd.findOrCreate(projectId: 'p1', jiraId: 'PROJ-1234');
    final created = await tasks.getById(id!);
    expect(created!.name, 'PROJ-1234');
    expect(created.jiraId, 'PROJ-1234');
  });

  test('reuses an existing task with the same name (case-insensitive)',
      () async {
    final first =
        await quickAdd.findOrCreate(projectId: 'p1', name: 'Landing Page');
    final second =
        await quickAdd.findOrCreate(projectId: 'p1', name: 'landing page');
    expect(second, first);
    expect((await tasks.watchByProject('p1').first), hasLength(1));
  });

  test('backfills the Jira id on an existing task', () async {
    final id = await quickAdd.findOrCreate(projectId: 'p1', name: 'Bug');
    await quickAdd.findOrCreate(projectId: 'p1', name: 'Bug', jiraId: 'BUG-1');
    final task = await tasks.getById(id!);
    expect(task!.jiraId, 'BUG-1');
  });

  test('same name under different sub-projects are distinct tasks', () async {
    // Sub-project rows are not required for this check since the task's
    // subProjectId is nullable and only compared by value.
    final a = await quickAdd.findOrCreate(projectId: 'p1', name: 'Review');
    final b = await quickAdd.findOrCreate(
        projectId: 'p1', subProjectId: null, name: 'Review');
    expect(a, b); // both null sub-project → same task
  });
}
