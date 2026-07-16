import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../domain/entities/project.dart';
import '../../domain/services/session_aggregator.dart';
import '../app_state/app_providers.dart';
import '../export/export_screen.dart';
import 'period_selector.dart';
import 'report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(reportTreeProvider).valueOrNull ?? ReportTree.empty;
    final projects =
        ref.watch(projectsProvider(workspaceId)).valueOrNull ?? const [];
    final projectsById = {for (final p in projects) p.id: p};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Eksport i kopie',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ExportScreen(workspaceId: workspaceId),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const PeriodSelector(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Razem: ${formatDurationShort(tree.total)}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tree.projects.isEmpty
                ? const Center(child: Text('Brak danych w tym okresie'))
                : ListView(
                    children: [
                      for (final node in tree.projects)
                        _ProjectNodeTile(
                          node: node,
                          project: projectsById[node.projectId],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectNodeTile extends ConsumerWidget {
  const _ProjectNodeTile({required this.node, required this.project});

  final ProjectNode node;
  final Project? project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref
            .watch(subProjectsProvider(node.projectId))
            .valueOrNull ??
        const [];
    final subNames = {for (final s in subs) s.id: s.name};

    return ExpansionTile(
      leading: CircleAvatar(
        radius: 10,
        backgroundColor: Color(project?.color ?? 0xFF9E9E9E),
      ),
      title: Text(project?.name ?? 'Projekt'),
      trailing: Text(formatDurationShort(node.total),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        for (final sub in node.subProjects)
          _SubProjectNodeTile(
            projectId: node.projectId,
            node: sub,
            name: subNames[sub.subProjectId] ?? 'Podprojekt',
          ),
        for (final task in node.tasks)
          _TaskNodeTile(projectId: node.projectId, node: task, indent: 1),
      ],
    );
  }
}

class _SubProjectNodeTile extends ConsumerWidget {
  const _SubProjectNodeTile({
    required this.projectId,
    required this.node,
    required this.name,
  });

  final String projectId;
  final SubProjectNode node;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.only(left: 32, right: 16),
      leading: const Icon(Icons.folder_outlined),
      title: Text(name),
      trailing: Text(formatDurationShort(node.total),
          style: const TextStyle(fontWeight: FontWeight.w500)),
      children: [
        for (final task in node.tasks)
          _TaskNodeTile(projectId: projectId, node: task, indent: 2),
      ],
    );
  }
}

class _TaskNodeTile extends ConsumerWidget {
  const _TaskNodeTile({
    required this.projectId,
    required this.node,
    required this.indent,
  });

  final String projectId;
  final TaskNode node;
  final int indent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider(projectId)).valueOrNull ?? const [];
    final task = node.taskId == null
        ? null
        : tasks.where((t) => t.id == node.taskId).firstOrNull;
    final title = node.taskId == null
        ? '(bez zadania)'
        : (task?.name ?? 'Zadanie');

    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 32.0 + indent * 16, right: 16),
      leading: const Icon(Icons.check_circle_outline),
      title: Text(title),
      subtitle: task?.jiraId == null ? null : Text(task!.jiraId!),
      trailing: Text('${formatDurationShort(node.total)} · ${node.entries.length}×'),
      children: [
        for (final entry in node.entries)
          Padding(
            padding: EdgeInsets.only(left: 48.0 + indent * 16, right: 16, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _sessionLabel(entry),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(formatDurationShort(entry.duration),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }

  String _sessionLabel(SessionEntry entry) {
    final start = entry.session.startLocal;
    final end = entry.session.endLocal;
    final date = formatDayMonth(start);
    final range = end == null
        ? formatTimeOfDay(start)
        : '${formatTimeOfDay(start)}–${formatTimeOfDay(end)}';
    return '$date  $range';
  }
}
