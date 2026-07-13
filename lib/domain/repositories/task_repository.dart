import '../entities/task.dart';

abstract interface class TaskRepository {
  Stream<List<Task>> watchByProject(
    String projectId, {
    bool includeArchived = false,
  });

  Future<Task?> getById(String id);

  Future<void> upsert(Task task);

  /// Physical delete. Throws [StateError] when the task has any sessions.
  Future<void> delete(String id);
}
