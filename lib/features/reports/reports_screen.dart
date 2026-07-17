import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../core/ui/donut_gauge.dart';
import '../../core/ui/metric_bar.dart';
import '../../core/ui/td_card.dart';
import '../../core/ui/td_tokens.dart';
import '../../domain/entities/project.dart';
import '../../domain/services/report_range.dart';
import '../../domain/services/session_aggregator.dart';
import '../app_state/app_providers.dart';
import '../export/export_screen.dart';
import 'period_selector.dart';
import 'report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key, required this.workspaceId});

  final String workspaceId;

  static int _sessionsIn(ProjectNode p) {
    var n = p.tasks.fold(0, (a, t) => a + t.entries.length);
    for (final s in p.subProjects) {
      n += s.tasks.fold(0, (a, t) => a + t.entries.length);
    }
    return n;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(reportTreeProvider).valueOrNull ?? ReportTree.empty;
    final period = ref.watch(reportPeriodProvider);
    final projects =
        ref.watch(projectsProvider(workspaceId)).valueOrNull ?? const [];
    final projectsById = {for (final p in projects) p.id: p};
    final workspace = (ref.watch(workspacesProvider).valueOrNull ?? const [])
        .where((w) => w.id == workspaceId)
        .firstOrNull;

    final sessions =
        tree.projects.fold(0, (a, p) => a + _sessionsIn(p));
    final avg = sessions == 0
        ? Duration.zero
        : Duration(seconds: tree.total.inSeconds ~/ sessions);
    final maxTotal = tree.projects.isEmpty
        ? 0
        : tree.projects
            .map((p) => p.total.inSeconds)
            .reduce((a, b) => a > b ? a : b);

    // Weekly goal progress ring — only meaningful for the week period.
    final goalMin = workspace?.weeklyGoalMinutes;
    final showGoal = period == ReportPeriod.week && goalMin != null && goalMin > 0;
    final goalFraction = showGoal ? tree.total.inMinutes / goalMin : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporty'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Eksport i kopie',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ExportScreen(workspaceId: workspaceId),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const PeriodSelector(),
          const SizedBox(height: 14),
          _SummaryCard(
            total: tree.total,
            sessions: sessions,
            avg: avg,
            projects: tree.projects.length,
            goalFraction: goalFraction,
          ),
          const SizedBox(height: 18),
          if (tree.projects.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('Brak danych w tym okresie')),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'PROJEKTY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: context.td.faint,
                ),
              ),
            ),
            for (final node in tree.projects)
              _ProjectNodeTile(
                node: node,
                project: projectsById[node.projectId],
                maxTotalSeconds: maxTotal,
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.sessions,
    required this.avg,
    required this.projects,
    required this.goalFraction,
  });

  final Duration total;
  final int sessions;
  final Duration avg;
  final int projects;
  final double? goalFraction;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final f = goalFraction;
    final goalColor = f == null
        ? context.cs.primary
        : (f >= 1
            ? td.good
            : (f >= 0.6 ? context.cs.primary : td.warn));

    return TdCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (f != null) ...[
            DonutGauge(
              value: f,
              color: goalColor,
              size: 88,
              stroke: 10,
              center: Text(
                '${(f * 100).round()}%',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: goalColor,
                ),
              ),
            ),
            const SizedBox(width: 18),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kept as a single string for the widget test.
                Text(
                  'Razem: ${formatDurationShort(total)}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                ),
                if (f != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'z celu tygodnia',
                      style: TextStyle(fontSize: 12, color: td.faint),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _MiniStat(label: 'Sesje', value: '$sessions'),
                    _MiniStat(
                        label: 'Śr. sesja',
                        value: sessions == 0 ? '—' : formatDurationShort(avg)),
                    _MiniStat(label: 'Projekty', value: '$projects'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w700,
            color: td.faint,
          ),
        ),
      ],
    );
  }
}

class _ProjectNodeTile extends ConsumerWidget {
  const _ProjectNodeTile({
    required this.node,
    required this.project,
    required this.maxTotalSeconds,
  });

  final ProjectNode node;
  final Project? project;
  final int maxTotalSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final td = context.td;
    final subs =
        ref.watch(subProjectsProvider(node.projectId)).valueOrNull ?? const [];
    final subNames = {for (final s in subs) s.id: s.name};
    final color = Color(project?.color ?? 0xFF9E9E9E);
    final share =
        maxTotalSeconds == 0 ? 0.0 : node.total.inSeconds / maxTotalSeconds;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TdCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent, splashColor: td.cardAlt),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            childrenPadding: const EdgeInsets.only(bottom: 6),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        project?.name ?? 'Projekt',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    Text(
                      formatDurationShort(node.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                MetricBar(value: share, color: color),
              ],
            ),
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
          ),
        ),
      ),
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
      tilePadding: const EdgeInsets.only(left: 28, right: 14),
      dense: true,
      leading: Icon(Icons.folder_outlined, color: context.td.faint, size: 20),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Text(formatDurationShort(node.total),
          style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final td = context.td;
    final tasks = ref.watch(tasksProvider(projectId)).valueOrNull ?? const [];
    final task = node.taskId == null
        ? null
        : tasks.where((t) => t.id == node.taskId).firstOrNull;
    final title = node.taskId == null ? '(bez zadania)' : (task?.name ?? 'Zadanie');

    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 28.0 + indent * 14, right: 14),
      dense: true,
      leading: Icon(Icons.check_circle_outline, color: td.faint, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: task?.jiraId == null
          ? null
          : Text(task!.jiraId!,
              style: TextStyle(color: td.infoInk, fontSize: 12)),
      trailing: Text('${formatDurationShort(node.total)} · ${node.entries.length}×',
          style: TextStyle(color: td.faint, fontSize: 12.5)),
      children: [
        for (final entry in node.entries)
          Padding(
            padding:
                EdgeInsets.only(left: 44.0 + indent * 14, right: 14, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(_sessionLabel(entry),
                      style: TextStyle(color: td.faint, fontSize: 12.5)),
                ),
                Text(formatDurationShort(entry.duration),
                    style: TextStyle(color: td.faint, fontSize: 12.5)),
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
