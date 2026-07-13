import '../entities/workspace.dart';

abstract interface class WorkspaceRepository {
  Stream<List<Workspace>> watchAll({bool includeArchived = false});

  Future<Workspace?> getById(String id);

  Future<void> upsert(Workspace workspace);

  Future<bool> hasAny();
}
