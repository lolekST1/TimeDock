import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/repositories/session_repository.dart';

/// Display data for a [SessionContext]: the names to render and the project
/// color, resolved from the current projects/sub-projects/tasks.
class ContextLabel {
  const ContextLabel({
    required this.projectName,
    this.subProjectName,
    this.taskName,
    this.taskJiraId,
    required this.color,
  });

  final String projectName;
  final String? subProjectName;
  final String? taskName;
  final String? taskJiraId;
  final int color;

  /// e.g. "Projekt2 › Podprojekt1 › PROJ-987".
  String get path => [
        projectName,
        if (subProjectName != null) subProjectName,
        if (taskName != null) taskName,
      ].join(' › ');
}

final contextLabelProvider =
    FutureProvider.family<ContextLabel?, SessionContext>((ref, context) async {
  final project =
      await ref.watch(projectRepositoryProvider).getById(context.projectId);
  if (project == null) return null;

  String? subName;
  if (context.subProjectId != null) {
    subName = (await ref
            .watch(subProjectRepositoryProvider)
            .getById(context.subProjectId!))
        ?.name;
  }

  String? taskName;
  String? taskJira;
  if (context.taskId != null) {
    final task =
        await ref.watch(taskRepositoryProvider).getById(context.taskId!);
    taskName = task?.name;
    taskJira = task?.jiraId;
  }

  return ContextLabel(
    projectName: project.name,
    subProjectName: subName,
    taskName: taskName,
    taskJiraId: taskJira,
    color: project.color,
  );
});
