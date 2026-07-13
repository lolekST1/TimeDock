import '../entities/time_session.dart';
import 'time_rules.dart';

/// A session together with the portion of its duration that falls inside the
/// report's date range (sessions crossing the range edge count partially).
class SessionEntry {
  const SessionEntry({required this.session, required this.duration});

  final TimeSession session;
  final Duration duration;
}

/// Sessions of one task summed into a single row; `taskId == null` groups the
/// sessions logged without a task ("(bez zadania)").
class TaskNode {
  const TaskNode({
    required this.taskId,
    required this.total,
    required this.entries,
  });

  final String? taskId;
  final Duration total;
  final List<SessionEntry> entries;
}

class SubProjectNode {
  const SubProjectNode({
    required this.subProjectId,
    required this.total,
    required this.tasks,
  });

  final String subProjectId;
  final Duration total;
  final List<TaskNode> tasks;
}

class ProjectNode {
  const ProjectNode({
    required this.projectId,
    required this.total,
    required this.subProjects,
    required this.tasks,
  });

  final String projectId;
  final Duration total;
  final List<SubProjectNode> subProjects;

  /// Tasks (and the "(bez zadania)" group) logged directly under the project,
  /// without a sub-project.
  final List<TaskNode> tasks;
}

class ReportTree {
  const ReportTree({required this.total, required this.projects});

  final Duration total;
  final List<ProjectNode> projects;

  static const empty = ReportTree(total: Duration.zero, projects: []);
}

/// Pure aggregation of sessions into the drill-down tree
/// Project → SubProject → Task → Sessions, with durations clipped to the
/// report's local-day range. Statistics and exports build on the same input,
/// so this stays a pure function over sessions.
abstract final class SessionAggregator {
  static ReportTree aggregate({
    required Iterable<TimeSession> sessions,
    required DateTime firstDay,
    required DateTime lastDay,
    DateTime? nowUtc,
    int? nowOffsetMinutes,
  }) {
    // projectId -> subProjectId? -> taskId? -> entries
    final buckets =
        <String, Map<String?, Map<String?, List<SessionEntry>>>>{};
    var total = Duration.zero;

    for (final session in sessions) {
      if (session.isRunning && nowUtc == null) continue;
      final inRange = TimeRules.durationInDayRange(
        session,
        firstDay,
        lastDay,
        nowUtc: nowUtc,
        nowOffsetMinutes: nowOffsetMinutes,
      );
      if (inRange == Duration.zero) continue;
      total += inRange;
      buckets
          .putIfAbsent(session.projectId, () => {})
          .putIfAbsent(session.subProjectId, () => {})
          .putIfAbsent(session.taskId, () => [])
          .add(SessionEntry(session: session, duration: inRange));
    }

    final projects = <ProjectNode>[];
    buckets.forEach((projectId, bySubProject) {
      final subProjects = <SubProjectNode>[];
      var directTasks = <TaskNode>[];
      var projectTotal = Duration.zero;

      bySubProject.forEach((subProjectId, byTask) {
        final tasks = _taskNodes(byTask);
        final subTotal =
            tasks.fold(Duration.zero, (sum, t) => sum + t.total);
        projectTotal += subTotal;
        if (subProjectId == null) {
          directTasks = tasks;
        } else {
          subProjects.add(SubProjectNode(
            subProjectId: subProjectId,
            total: subTotal,
            tasks: tasks,
          ));
        }
      });

      subProjects.sort((a, b) => b.total.compareTo(a.total));
      projects.add(ProjectNode(
        projectId: projectId,
        total: projectTotal,
        subProjects: subProjects,
        tasks: directTasks,
      ));
    });

    projects.sort((a, b) => b.total.compareTo(a.total));
    return ReportTree(total: total, projects: projects);
  }

  static List<TaskNode> _taskNodes(
      Map<String?, List<SessionEntry>> byTask) {
    final nodes = <TaskNode>[];
    byTask.forEach((taskId, entries) {
      entries.sort((a, b) => a.session.startUtc.compareTo(b.session.startUtc));
      nodes.add(TaskNode(
        taskId: taskId,
        total: entries.fold(Duration.zero, (sum, e) => sum + e.duration),
        entries: entries,
      ));
    });
    // Largest first; the "(bez zadania)" group always last.
    nodes.sort((a, b) {
      if ((a.taskId == null) != (b.taskId == null)) {
        return a.taskId == null ? 1 : -1;
      }
      return b.total.compareTo(a.total);
    });
    return nodes;
  }
}
