import 'package:drift/drift.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../db/database.dart';
import '../db/mappers.dart';

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db);

  final TimeDockDatabase _db;

  @override
  Stream<List<Task>> watchByProject(
    String projectId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.tasks)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.watch().map(
        (rows) => rows.map((r) => r.toEntity()).toList(growable: false));
  }

  @override
  Future<Task?> getById(String id) async {
    final row = await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<void> upsert(Task task) =>
      _db.into(_db.tasks).insertOnConflictUpdate(task.toCompanion());

  @override
  Future<void> delete(String id) async {
    final hasSessions = await (_db.selectOnly(_db.timeSessions)
          ..addColumns([_db.timeSessions.id])
          ..where(_db.timeSessions.taskId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (hasSessions != null) {
      throw StateError('Task $id has sessions; archive it instead.');
    }
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }
}
