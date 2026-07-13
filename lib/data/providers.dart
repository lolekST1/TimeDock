import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/project_repository.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/repositories/sub_project_repository.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import 'db/database.dart';
import 'repositories/drift_project_repository.dart';
import 'repositories/drift_session_repository.dart';
import 'repositories/drift_sub_project_repository.dart';
import 'repositories/drift_task_repository.dart';
import 'repositories/drift_workspace_repository.dart';
import 'seed.dart';

final databaseProvider = Provider<TimeDockDatabase>((ref) {
  final db = TimeDockDatabase(driftDatabase(name: 'timedock'));
  ref.onDispose(db.close);
  return db;
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
    (ref) => DriftWorkspaceRepository(ref.watch(databaseProvider)));

final projectRepositoryProvider = Provider<ProjectRepository>(
    (ref) => DriftProjectRepository(ref.watch(databaseProvider)));

final subProjectRepositoryProvider = Provider<SubProjectRepository>(
    (ref) => DriftSubProjectRepository(ref.watch(databaseProvider)));

final taskRepositoryProvider = Provider<TaskRepository>(
    (ref) => DriftTaskRepository(ref.watch(databaseProvider)));

final sessionRepositoryProvider = Provider<SessionRepository>(
    (ref) => DriftSessionRepository(ref.watch(databaseProvider)));

final seederProvider = Provider<DatabaseSeeder>((ref) => DatabaseSeeder(
      workspaces: ref.watch(workspaceRepositoryProvider),
      projects: ref.watch(projectRepositoryProvider),
      subProjects: ref.watch(subProjectRepositoryProvider),
    ));
