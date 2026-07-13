import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../domain/entities/project.dart';
import '../app_state/app_providers.dart';
import '../history/history_screen.dart';
import '../reports/reports_screen.dart';
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
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected?.id,
            items: [
              for (final w in workspaces)
                DropdownMenuItem(value: w.id, child: Text(w.name)),
            ],
            onChanged: (id) {
              if (id != null) {
                ref.read(selectedWorkspaceProvider.notifier).select(id);
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Statystyki',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StatsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Raporty',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReportsScreen(workspaceId: selectedId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historia',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HistoryScreen(workspaceId: selectedId),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addProject(context, ref, selectedId),
        icon: const Icon(Icons.add),
        label: const Text('Projekt'),
      ),
      bottomNavigationBar:
          active == null ? null : ActiveTimerBar(session: active),
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
        if (recents.isNotEmpty) ...[
          const _Header('Ostatnio używane'),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final ctx in recents)
                    RecentContextTile(context: ctx),
                ],
              ),
            ),
          ),
        ],
        if (favorites.isNotEmpty) ...[
          const _Header('Ulubione'),
          _ProjectGrid(projects: favorites),
        ],
        const _Header('Wszystkie projekty'),
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
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
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
          maxCrossAxisExtent: 200,
          childAspectRatio: 1.4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProjectTile(project: projects[index]),
          childCount: projects.length,
        ),
      ),
    );
  }
}
