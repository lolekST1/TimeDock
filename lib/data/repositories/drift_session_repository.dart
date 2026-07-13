import 'package:drift/drift.dart';

import '../../domain/entities/time_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../db/database.dart';
import '../db/mappers.dart';

class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(this._db);

  final TimeDockDatabase _db;

  @override
  Stream<TimeSession?> watchActive() {
    final query = _db.select(_db.timeSessions)
      ..where((s) => s.endUtcMillis.isNull())
      ..limit(1);
    return query.watchSingleOrNull().map((row) => row?.toEntity());
  }

  @override
  Future<TimeSession?> getActive() async {
    final row = await (_db.select(_db.timeSessions)
          ..where((s) => s.endUtcMillis.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row?.toEntity();
  }

  SimpleSelectStatement<$TimeSessionsTable, TimeSessionRow> _overlapping(
    String workspaceId,
    DateTime fromUtc,
    DateTime toUtc,
  ) {
    final from = fromUtc.millisecondsSinceEpoch;
    final to = toUtc.millisecondsSinceEpoch;
    return _db.select(_db.timeSessions)
      ..where((s) =>
          s.workspaceId.equals(workspaceId) &
          s.startUtcMillis.isSmallerThanValue(to) &
          (s.endUtcMillis.isNull() |
              s.endUtcMillis.isBiggerThanValue(from)))
      ..orderBy([(s) => OrderingTerm.asc(s.startUtcMillis)]);
  }

  @override
  Stream<List<TimeSession>> watchOverlappingRange(
    String workspaceId,
    DateTime fromUtc,
    DateTime toUtc,
  ) =>
      _overlapping(workspaceId, fromUtc, toUtc).watch().map(
          (rows) => rows.map((r) => r.toEntity()).toList(growable: false));

  @override
  Future<List<TimeSession>> listOverlappingRange(
    String workspaceId,
    DateTime fromUtc,
    DateTime toUtc,
  ) async {
    final rows = await _overlapping(workspaceId, fromUtc, toUtc).get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  @override
  Stream<List<SessionContext>> watchRecentContexts(
    String workspaceId, {
    int limit = 5,
  }) {
    // Scan newest sessions and deduplicate contexts in memory: the query stays
    // trivial and "recent" is bounded anyway.
    final query = _db.select(_db.timeSessions)
      ..where((s) => s.workspaceId.equals(workspaceId))
      ..orderBy([(s) => OrderingTerm.desc(s.startUtcMillis)])
      ..limit(200);
    return query.watch().map((rows) {
      final seen = <SessionContext>{};
      final result = <SessionContext>[];
      for (final row in rows) {
        final context = SessionContext(
          workspaceId: row.workspaceId,
          projectId: row.projectId,
          subProjectId: row.subProjectId,
          taskId: row.taskId,
        );
        if (seen.add(context)) {
          result.add(context);
          if (result.length >= limit) break;
        }
      }
      return result;
    });
  }

  @override
  Future<void> upsert(TimeSession session) => _db
      .into(_db.timeSessions)
      .insertOnConflictUpdate(session.toCompanion());

  @override
  Future<void> upsertAll(List<TimeSession> sessions) =>
      _db.transaction(() async {
        for (final session in sessions) {
          await upsert(session);
        }
      });

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.timeSessions)..where((s) => s.id.equals(id))).go();

  Future<bool> _any(Expression<bool> predicate) async {
    final row = await (_db.selectOnly(_db.timeSessions)
          ..addColumns([_db.timeSessions.id])
          ..where(predicate)
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<bool> anyForProject(String projectId) =>
      _any(_db.timeSessions.projectId.equals(projectId));

  @override
  Future<bool> anyForSubProject(String subProjectId) =>
      _any(_db.timeSessions.subProjectId.equals(subProjectId));

  @override
  Future<bool> anyForTask(String taskId) =>
      _any(_db.timeSessions.taskId.equals(taskId));
}
