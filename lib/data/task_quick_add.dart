import 'package:uuid/uuid.dart';

import '../domain/entities/task.dart';
import '../domain/repositories/task_repository.dart';

/// Ad-hoc task entry: lets the user type a task name and/or Jira id during a
/// session without pre-defining a dictionary. Finds an existing task with the
/// same name under the project (and sub-project), otherwise creates one.
/// Returns the task id, or null when nothing meaningful was entered.
class TaskQuickAdd {
  TaskQuickAdd(this._tasks, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final TaskRepository _tasks;
  final Uuid _uuid;

  Future<String?> findOrCreate({
    required String projectId,
    String? subProjectId,
    String? name,
    String? jiraId,
    DateTime Function()? nowUtc,
  }) async {
    final now = (nowUtc ?? () => DateTime.now().toUtc())();
    final trimmedName = name?.trim() ?? '';
    final trimmedJira = jiraId?.trim() ?? '';
    if (trimmedName.isEmpty && trimmedJira.isEmpty) return null;

    // If only a Jira id was given, use it as the task name too.
    final effectiveName = trimmedName.isEmpty ? trimmedJira : trimmedName;
    final jira = trimmedJira.isEmpty ? null : trimmedJira;

    final existing = await _tasks.watchByProject(projectId).first;
    final match = existing
        .where((t) =>
            t.subProjectId == subProjectId &&
            t.name.toLowerCase() == effectiveName.toLowerCase())
        .firstOrNull;

    if (match != null) {
      // Backfill the Jira id if the user just supplied one.
      if (jira != null && match.jiraId != jira) {
        await _tasks.upsert(match.copyWith(jiraId: jira, updatedAt: now));
      }
      return match.id;
    }

    final id = _uuid.v4();
    await _tasks.upsert(Task(
      id: id,
      projectId: projectId,
      subProjectId: subProjectId,
      name: effectiveName,
      jiraId: jira,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }
}
