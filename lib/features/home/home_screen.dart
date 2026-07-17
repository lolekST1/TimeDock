import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/time_format.dart';
import '../../core/ui/section_label.dart';
import '../../core/ui/td_tokens.dart';
import '../../data/providers.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/services/day_timeline.dart';
import '../app_state/app_providers.dart';
import '../export/export_screen.dart';
import '../history/history_providers.dart';
import '../history/history_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import 'widgets/active_timer_bar.dart';
import 'widgets/entity_dialogs.dart';
import 'widgets/project_tile.dart';
import 'widgets/recent_context_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const [];
    final selectedId = ref.watch(selectedWorkspaceProvider);
    final active = ref.watch(activeSessionProvider).valueOrNull;

    if (selectedId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selected = workspaces.where((w) => w.id == selectedId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: _WorkspacePill(
          workspaces: workspaces,
          selected: selected,
          onSelect: (id) =>
              ref.read(selectedWorkspaceProvider.notifier).select(id),
        ),
        actions: [
          _TodayChip(workspaceId: selectedId),
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Statystyki',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ustawienia',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addProject(context, ref, selectedId),
        icon: const Icon(Icons.add),
        label: const Text('Projekt'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active != null) ActiveTimerBar(session: active),
            _BottomNav(workspaceId: selectedId),
          ],
        ),
      ),
      body: _HomeBody(workspaceId: selectedId),
    );
  }

  Future<void> _addProject(
      BuildContext context, WidgetRef ref, String workspaceId) async {
    final name = await promptForName(context, title: 'Nowy projekt');
    if (name == null) return;
    final now = DateTime.now().toUtc();
    // Give new projects a color derived from their name for instant identity.
    final color = Colors.primaries[name.hashCode.abs() % Colors.primaries.length]
        .shade600
        .toARGB32();
    await ref.read(projectRepositoryProvider).upsert(Project(
          id: const Uuid().v4(),
          workspaceId: workspaceId,
          name: name,
          color: color,
          createdAt: now,
          updatedAt: now,
        ));
  }
}

/// The workspace switcher, styled as a pill that opens a menu.
class _WorkspacePill extends StatelessWidget {
  const _WorkspacePill({
    required this.workspaces,
    required this.selected,
    required this.onSelect,
  });

  final List<Workspace> workspaces;
  final Workspace? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final seed =
        selected != null ? Color(selected!.colorSeed) : context.cs.primary;
    return Material(
      color: td.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: td.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<String>(
        onSelected: onSelect,
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          for (final w in workspaces)
            PopupMenuItem<String>(
              value: w.id,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(w.colorSeed),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(w.name),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [seed, td.accent2]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                selected?.name ?? 'Workspace',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(width: 3),
              Icon(Icons.expand_more_rounded, size: 18, color: td.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Dziś · Xh Ym" — today's tracked total for the selected workspace.
class _TodayChip extends ConsumerWidget {
  const _TodayChip({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final entries = ref
            .watch(dayTimelineProvider(DayKey(workspaceId, today)))
            .valueOrNull ??
        const [];
    final total = DayTimeline.trackedTotal(entries);
    if (total.inMinutes < 1) return const SizedBox.shrink();
    final td = context.td;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: td.goodBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: td.good, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              'Dziś · ${formatDurationShort(total)}',
              style: TextStyle(
                color: td.goodInk,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: td.card,
        border: Border(top: BorderSide(color: td.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            _NavItem(icon: Icons.home_rounded, label: 'Dom', active: true),
            _NavItem(
              icon: Icons.schedule_rounded,
              label: 'Historia',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => HistoryScreen(workspaceId: workspaceId))),
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Raporty',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReportsScreen(workspaceId: workspaceId))),
            ),
            _NavItem(
              icon: Icons.ios_share_rounded,
              label: 'Eksport',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ExportScreen(workspaceId: workspaceId))),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final color = active ? context.cs.primary : td.faint;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects =
        ref.watch(projectsProvider(workspaceId)).valueOrNull ?? const [];
    final recents =
        ref.watch(recentContextsProvider(workspaceId)).valueOrNull ?? const [];
    final favorites = projects.where((p) => p.isFavorite).toList();

    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 6)),
        if (recents.isNotEmpty) ...[
          _sliverHeader(SectionLabel('Ostatnio używane', count: recents.length)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(
              children: [for (final ctx in recents) RecentContextTile(context: ctx)],
            ),
          ),
        ],
        if (favorites.isNotEmpty) ...[
          _sliverHeader(const SectionLabel('Ulubione')),
          _ProjectGrid(projects: favorites),
        ],
        _sliverHeader(const SectionLabel('Wszystkie projekty')),
        if (projects.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Brak projektów. Dodaj pierwszy przyciskiem +.'),
              ),
            ),
          )
        else
          _ProjectGrid(projects: projects),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _sliverHeader(Widget child) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverToBoxAdapter(child: child),
      );
}

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: 1.05,
          crossAxisSpacing: 11,
          mainAxisSpacing: 11,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProjectTile(project: projects[index]),
          childCount: projects.length,
        ),
      ),
    );
  }
}
