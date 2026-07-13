import '../entities/sub_project.dart';

abstract interface class SubProjectRepository {
  Stream<List<SubProject>> watchByProject(
    String projectId, {
    bool includeArchived = false,
  });

  Future<SubProject?> getById(String id);

  Future<void> upsert(SubProject subProject);

  /// Physical delete. Throws [StateError] when the sub-project has sessions.
  Future<void> delete(String id);
}
