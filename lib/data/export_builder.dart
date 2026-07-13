import '../domain/entities/time_session.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/repositories/sub_project_repository.dart';
import '../domain/repositories/task_repository.dart';
import '../domain/repositories/workspace_repository.dart';
import '../domain/services/csv_exporter.dart';
import '../domain/services/report_range.dart';
import '../domain/services/session_aggregator.dart';

/// Turns stored sessions (ids) into name-resolved export rows for a report
/// range. Resolution is cached per id so a month export stays cheap.
class ExportBuilder {
  ExportBuilder({
    required this.workspaces,
    required this.projects,
    required this.subProjects,
    required this.tasks,
    required this.sessions,
  });

  final WorkspaceRepository workspaces;
  final ProjectRepository projects;
  final SubProjectRepository subProjects;
  final TaskRepository tasks;
  final SessionRepository sessions;

  final _projectNames = <String, String>{};
  final _subProjectNames = <String, String>{};
  final _taskInfo = <String, ({String name, String? jira})>{};

  Future<String> _workspaceName(String id) async =>
      (await workspaces.getById(id))?.name ?? '';

  Future<String> _projectName(String id) async =>
      _projectNames[id] ??= (await projects.getById(id))?.name ?? '';

  Future<String?> _subProjectName(String? id) async {
    if (id == null) return null;
    return _subProjectNames[id] ??= (await subProjects.getById(id))?.name ?? '';
  }

  Future<({String name, String? jira})?> _task(String? id) async {
    if (id == null) return null;
    final cached = _taskInfo[id];
    if (cached != null) return cached;
    final task = await tasks.getById(id);
    final info = (name: task?.name ?? '', jira: task?.jiraId);
    _taskInfo[id] = info;
    return info;
  }

  String _date(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

  String _time(DateTime local) =>
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  Future<List<TimeSession>> _sessionsInRange(
      String workspaceId, ReportRange range) async {
    final from = range.firstDay.subtract(const Duration(days: 1));
    final to = range.lastDay.add(const Duration(days: 2));
    final all = await sessions.listOverlappingRange(workspaceId, from, to);
    // Export finished sessions whose local start day falls in the range.
    return all.where((s) {
      if (s.isRunning) return false;
      final day = DateTime.utc(
          s.startLocal.year, s.startLocal.month, s.startLocal.day);
      return range.contains(day);
    }).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  Future<List<ExportRow>> perSessionRows(
      String workspaceId, ReportRange range) async {
    final workspaceName = await _workspaceName(workspaceId);
    final inRange = await _sessionsInRange(workspaceId, range);
    final rows = <ExportRow>[];
    for (final s in inRange) {
      final task = await _task(s.taskId);
      rows.add(ExportRow(
        date: _date(s.startLocal),
        start: _time(s.startLocal),
        end: s.endLocal == null ? '' : _time(s.endLocal!),
        duration: s.duration,
        workspace: workspaceName,
        project: await _projectName(s.projectId),
        subProject: await _subProjectName(s.subProjectId),
        task: task?.name,
        jiraId: task?.jira,
        comment: s.comment,
      ));
    }
    return rows;
  }

  Future<List<AggregateRow>> aggregateRows(
      String workspaceId, ReportRange range) async {
    final inRange = await _sessionsInRange(workspaceId, range);
    final tree = SessionAggregator.aggregate(
      sessions: inRange,
      firstDay: range.firstDay,
      lastDay: range.lastDay,
    );
    final rows = <AggregateRow>[];
    for (final project in tree.projects) {
      final projectName = await _projectName(project.projectId);
      for (final task in project.tasks) {
        rows.add(await _aggregateRow(projectName, null, task));
      }
      for (final sub in project.subProjects) {
        final subName = await _subProjectName(sub.subProjectId);
        for (final task in sub.tasks) {
          rows.add(await _aggregateRow(projectName, subName, task));
        }
      }
    }
    return rows;
  }

  Future<AggregateRow> _aggregateRow(
      String projectName, String? subName, TaskNode task) async {
    final info = await _task(task.taskId);
    return AggregateRow(
      project: projectName,
      subProject: subName,
      task: task.taskId == null ? '(bez zadania)' : info?.name,
      jiraId: info?.jira,
      total: task.total,
      sessionCount: task.entries.length,
    );
  }
}
