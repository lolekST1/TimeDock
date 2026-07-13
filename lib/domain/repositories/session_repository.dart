import '../entities/time_session.dart';

/// A start-timer target: project with optional sub-project and task.
/// "Recently used" rows are exactly these, derived from session history.
class SessionContext {
  const SessionContext({
    required this.workspaceId,
    required this.projectId,
    this.subProjectId,
    this.taskId,
  });

  final String workspaceId;
  final String projectId;
  final String? subProjectId;
  final String? taskId;

  @override
  bool operator ==(Object other) =>
      other is SessionContext &&
      other.workspaceId == workspaceId &&
      other.projectId == projectId &&
      other.subProjectId == subProjectId &&
      other.taskId == taskId;

  @override
  int get hashCode => Object.hash(workspaceId, projectId, subProjectId, taskId);
}

abstract interface class SessionRepository {
  /// The single running session (endUtc == null) across all workspaces,
  /// or null. The database record is the source of truth for the timer.
  Stream<TimeSession?> watchActive();

  Future<TimeSession?> getActive();

  /// Finished and running sessions overlapping [fromUtc, toUtc).
  Stream<List<TimeSession>> watchOverlappingRange(
    String workspaceId,
    DateTime fromUtc,
    DateTime toUtc,
  );

  Future<List<TimeSession>> listOverlappingRange(
    String workspaceId,
    DateTime fromUtc,
    DateTime toUtc,
  );

  /// Most recent distinct contexts in a workspace, newest first.
  Stream<List<SessionContext>> watchRecentContexts(
    String workspaceId, {
    int limit = 5,
  });

  Future<void> upsert(TimeSession session);

  Future<void> upsertAll(List<TimeSession> sessions);

  Future<void> delete(String id);

  Future<bool> anyForProject(String projectId);

  Future<bool> anyForSubProject(String subProjectId);

  Future<bool> anyForTask(String taskId);
}
