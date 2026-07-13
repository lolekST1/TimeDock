import 'package:drift/drift.dart';

import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../db/database.dart';
import '../db/mappers.dart';

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._db);

  final TimeDockDatabase _db;

  @override
  Stream<List<Project>> watchByWorkspace(
    String workspaceId, {
    bool includeHidden = false,
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.projects)
      ..where((p) => p.workspaceId.equals(workspaceId))
      ..orderBy([
        (p) => OrderingTerm.asc(p.sortOrder),
        (p) => OrderingTerm.asc(p.name),
      ]);
    if (!includeHidden) {
      query.where((p) => p.isHidden.equals(false));
    }
    if (!includeArchived) {
      query.where((p) => p.isArchived.equals(false));
    }
    return query.watch().map(
        (rows) => rows.map((r) => r.toEntity()).toList(growable: false));
  }

  @override
  Future<Project?> getById(String id) async {
    final row = await (_db.select(_db.projects)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<void> upsert(Project project) =>
      _db.into(_db.projects).insertOnConflictUpdate(project.toCompanion());

  @override
  Future<void> delete(String id) async {
    final hasSessions = await (_db.selectOnly(_db.timeSessions)
          ..addColumns([_db.timeSessions.id])
          ..where(_db.timeSessions.projectId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (hasSessions != null) {
      throw StateError(
          'Project $id has sessions; archive it instead of deleting.');
    }
    await _db.transaction(() async {
      await (_db.delete(_db.tasks)..where((t) => t.projectId.equals(id))).go();
      await (_db.delete(_db.subProjects)
            ..where((s) => s.projectId.equals(id)))
          .go();
      await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
    });
  }
}
