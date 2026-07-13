import 'package:drift/drift.dart';

import '../../domain/entities/sub_project.dart';
import '../../domain/repositories/sub_project_repository.dart';
import '../db/database.dart';
import '../db/mappers.dart';

class DriftSubProjectRepository implements SubProjectRepository {
  DriftSubProjectRepository(this._db);

  final TimeDockDatabase _db;

  @override
  Stream<List<SubProject>> watchByProject(
    String projectId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.subProjects)
      ..where((s) => s.projectId.equals(projectId))
      ..orderBy([
        (s) => OrderingTerm.asc(s.sortOrder),
        (s) => OrderingTerm.asc(s.name),
      ]);
    if (!includeArchived) {
      query.where((s) => s.isArchived.equals(false));
    }
    return query.watch().map(
        (rows) => rows.map((r) => r.toEntity()).toList(growable: false));
  }

  @override
  Future<SubProject?> getById(String id) async {
    final row = await (_db.select(_db.subProjects)
          ..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<void> upsert(SubProject subProject) => _db
      .into(_db.subProjects)
      .insertOnConflictUpdate(subProject.toCompanion());

  @override
  Future<void> delete(String id) async {
    final hasSessions = await (_db.selectOnly(_db.timeSessions)
          ..addColumns([_db.timeSessions.id])
          ..where(_db.timeSessions.subProjectId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (hasSessions != null) {
      throw StateError(
          'Sub-project $id has sessions; archive it instead of deleting.');
    }
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.subProjectId.equals(id)))
          .write(const TasksCompanion(subProjectId: Value(null)));
      await (_db.delete(_db.subProjects)..where((s) => s.id.equals(id))).go();
    });
  }
}
