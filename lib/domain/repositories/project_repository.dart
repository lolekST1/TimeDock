import '../entities/project.dart';

abstract interface class ProjectRepository {
  Stream<List<Project>> watchByWorkspace(
    String workspaceId, {
    bool includeHidden = false,
    bool includeArchived = false,
  });

  Future<Project?> getById(String id);

  Future<void> upsert(Project project);

  /// Physical delete. Throws [StateError] when the project has any sessions —
  /// entities with history may only be archived (soft delete).
  Future<void> delete(String id);
}
