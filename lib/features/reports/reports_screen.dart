import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../domain/entities/project.dart';
import '../../domain/services/report_range.dart';
import '../../domain/services/session_aggregator.dart';
import '../app_state/app_providers.dart';
import '../export/export_screen.dart';
import 'report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final range = ref.watch(reportRangeProvider);
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ReportPeriod>(
              segments: const [
                ButtonSegment(value: ReportPeriod.day, label: Text('Dzień')),
                ButtonSegment(value: ReportPeriod.week, label: Text('Tydzień')),
                ButtonSegment(value: ReportPeriod.month, label: Text('Miesiąc')),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(reportPeriodProvider.notifier).state = s.first,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(ref, period, -1),
              ),
              Text(_rangeLabel(period, range),
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(ref, period, 1),
              ),
            ],
          ),
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

  void _shift(WidgetRef ref, ReportPeriod period, int direction) {
    final anchor = ref.read(reportAnchorProvider);
    ref.read(reportAnchorProvider.notifier).state =
        ReportRangeCalculator.shift(period, anchor, direction);
  }

  String _rangeLabel(ReportPeriod period, ReportRange range) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    switch (period) {
      case ReportPeriod.day:
        return '${d(range.firstDay)}.${range.firstDay.year}';
      case ReportPeriod.week:
        return '${d(range.firstDay)} – ${d(range.lastDay)}';
      case ReportPeriod.month:
        const months = [
          'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
          'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
        ];
        return '${months[range.firstDay.month - 1]} ${range.firstDay.year}';
    }
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
    final date =
        '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}';
    final range = end == null
        ? formatTimeOfDay(start)
        : '${formatTimeOfDay(start)}–${formatTimeOfDay(end)}';
    return '$date  $range';
  }
}
