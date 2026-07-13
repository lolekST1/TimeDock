import 'package:drift/drift.dart';

import '../../domain/entities/workspace.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../db/database.dart';
import '../db/mappers.dart';

class DriftWorkspaceRepository implements WorkspaceRepository {
  DriftWorkspaceRepository(this._db);

  final TimeDockDatabase _db;

  @override
  Stream<List<Workspace>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.workspaces)
      ..orderBy([(w) => OrderingTerm.asc(w.sortOrder)]);
    if (!includeArchived) {
      query.where((w) => w.isArchived.equals(false));
    }
    return query.watch().map(
        (rows) => rows.map((r) => r.toEntity()).toList(growable: false));
  }

  @override
  Future<Workspace?> getById(String id) async {
    final row = await (_db.select(_db.workspaces)
          ..where((w) => w.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  @override
  Future<void> upsert(Workspace workspace) =>
      _db.into(_db.workspaces).insertOnConflictUpdate(workspace.toCompanion());

  @override
  Future<bool> hasAny() async {
    final row = await (_db.selectOnly(_db.workspaces)
          ..addColumns([_db.workspaces.id])
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }
}
