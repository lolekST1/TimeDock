import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/colors.dart';
import '../../../data/providers.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/sub_project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../app_state/app_providers.dart';
import 'entity_dialogs.dart';

Future<void> showProjectSheet(BuildContext context, Project project) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProjectSheet(project: project),
  );
}

/// Long-press sheet: pick a sub-project/task before starting (2-tap path for a
/// new context) or manage the project. Tapping a sub-project or task starts
/// the timer in that context immediately and closes the sheet.
class _ProjectSheet extends ConsumerWidget {
  const _ProjectSheet({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live project so toggles (e.g. favorite) reflect immediately in
    // this sheet instead of only after returning to the home screen.
    final liveProject = (ref
                .watch(projectsProvider(project.workspaceId))
                .valueOrNull ??
            const [])
        .where((p) => p.id == project.id)
        .firstOrNull ??
        project;
    final allSubProjects =
        ref.watch(allSubProjectsProvider(project.id)).valueOrNull ?? const [];
    final subProjects =
        allSubProjects.where((s) => !s.isArchived).toList(growable: false);
    final archivedSubProjects =
        allSubProjects.where((s) => s.isArchived).toList(growable: false);
    final tasks =
        ref.watch(tasksProvider(project.id)).valueOrNull ?? const [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: Color(liveProject.color)),
              title: Text(liveProject.name,
                  style: Theme.of(context).textTheme.titleLarge),
              trailing: IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                tooltip: 'Start projektu',
                onPressed: () => _startAndClose(
                  context,
                  ref,
                  SessionContext(
                      workspaceId: project.workspaceId,
                      projectId: project.id),
                ),
              ),
            ),
            const Divider(height: 1),
            _ManageRow(project: liveProject),
            const Divider(height: 1),
            if (subProjects.isNotEmpty) ...[
              _SectionHeader(
                title: 'Podprojekty',
                onAdd: () => _addSubProject(context, ref),
              ),
              for (final sub in subProjects)
                _SubProjectTile(project: project, subProject: sub),
            ] else
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Dodaj podprojekt'),
                onTap: () => _addSubProject(context, ref),
              ),
            if (archivedSubProjects.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Zarchiwizowane podprojekty',
                    style: TextStyle(fontSize: 12)),
              ),
              for (final sub in archivedSubProjects)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_off_outlined),
                  title: Text(sub.name),
                  trailing: TextButton(
                    onPressed: () => ref
                        .read(subProjectRepositoryProvider)
                        .upsert(sub.copyWith(
                            isArchived: false,
                            updatedAt: DateTime.now().toUtc())),
                    child: const Text('Przywróć'),
                  ),
                ),
            ],
            _SectionHeader(
              title: 'Zadania',
              onAdd: () => _createTask(context, ref, projectId: project.id),
            ),
            for (final task in tasks.where((t) => t.subProjectId == null))
              _TaskTile(project: project, task: task),
            if (tasks.where((t) => t.subProjectId == null).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Brak zadań bez podprojektu'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addSubProject(BuildContext context, WidgetRef ref) async {
    final name = await promptForName(context, title: 'Nowy podprojekt');
    if (name == null) return;
    final now = DateTime.now().toUtc();
    await ref.read(subProjectRepositoryProvider).upsert(SubProject(
          id: const Uuid().v4(),
          projectId: project.id,
          name: name,
          createdAt: now,
          updatedAt: now,
        ));
  }

}

Future<void> _startAndClose(
    BuildContext context, WidgetRef ref, SessionContext ctx) async {
  await ref.read(timerServiceProvider).start(ctx);
  if (context.mounted) Navigator.of(context).pop();
}

/// Prompts for a task and persists it under the project (optionally under a
/// sub-project). Shared by the project-level and sub-project-level "add task".
Future<void> _createTask(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  String? subProjectId,
}) async {
  final result = await promptForTask(context);
  if (result == null) return;
  final now = DateTime.now().toUtc();
  await ref.read(taskRepositoryProvider).upsert(Task(
        id: const Uuid().v4(),
        projectId: projectId,
        subProjectId: subProjectId,
        name: result.name,
        jiraId: result.jiraId,
        createdAt: now,
        updatedAt: now,
      ));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
        ],
      ),
    );
  }
}

class _SubProjectTile extends ConsumerWidget {
  const _SubProjectTile({required this.project, required this.subProject});

  final Project project;
  final SubProject subProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = (ref.watch(tasksProvider(project.id)).valueOrNull ?? const [])
        .where((t) => t.subProjectId == subProject.id)
        .toList();
    return ExpansionTile(
      title: Text(subProject.name),
      leading: const Icon(Icons.folder_outlined),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: 'Start podprojektu',
            onPressed: () => _startAndClose(
              context,
              ref,
              SessionContext(
                workspaceId: project.workspaceId,
                projectId: project.id,
                subProjectId: subProject.id,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Zmień nazwę')),
              const PopupMenuItem(
                  value: 'archive', child: Text('Archiwizuj')),
            ],
          ),
        ],
      ),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [
        for (final task in tasks)
          _TaskTile(project: project, task: task),
        ListTile(
          dense: true,
          leading: const Icon(Icons.add),
          title: const Text('Dodaj zadanie'),
          onTap: () =>
              _createTask(context, ref, projectId: project.id,
                  subProjectId: subProject.id),
        ),
      ],
    );
  }


  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(subProjectRepositoryProvider);
    final now = DateTime.now().toUtc();
    switch (action) {
      case 'rename':
        final name = await promptForName(context,
            title: 'Nazwa podprojektu', initial: subProject.name);
        if (name != null) {
          await repo.upsert(subProject.copyWith(name: name, updatedAt: now));
        }
      case 'archive':
        await repo.upsert(subProject.copyWith(isArchived: true, updatedAt: now));
    }
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.project, required this.task});

  final Project project;
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.check_circle_outline),
      title: Text(task.name),
      subtitle: task.jiraId == null ? null : Text(task.jiraId!),
      onTap: () => _startAndClose(
        context,
        ref,
        SessionContext(
          workspaceId: project.workspaceId,
          projectId: project.id,
          subProjectId: task.subProjectId,
          taskId: task.id,
        ),
      ),
    );
  }
}

class _ManageRow extends ConsumerWidget {
  const _ManageRow({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(projectRepositoryProvider);
    return Wrap(
      spacing: 4,
      children: [
        TextButton.icon(
          icon: Icon(project.isFavorite
              ? Icons.star_rounded
              : Icons.star_border_rounded),
          label: const Text('Ulubiony'),
          onPressed: () => repo.upsert(project.copyWith(
              isFavorite: !project.isFavorite,
              updatedAt: DateTime.now().toUtc())),
        ),
        TextButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edytuj'),
          onPressed: () async {
            final name =
                await promptForName(context, title: 'Nazwa projektu', initial: project.name);
            if (name != null) {
              await repo.upsert(project.copyWith(
                  name: name, updatedAt: DateTime.now().toUtc()));
            }
          },
        ),
        TextButton.icon(
          icon: Icon(Icons.palette_outlined, color: Color(project.color)),
          label: const Text('Kolor'),
          onPressed: () async {
            final color = await pickEntityColor(context, project.color);
            if (color != null) {
              await repo.upsert(project.copyWith(
                  color: color, updatedAt: DateTime.now().toUtc()));
            }
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.visibility_off_outlined),
          label: Text(project.isHidden ? 'Odkryj' : 'Ukryj'),
          onPressed: () async {
            await repo.upsert(project.copyWith(
                isHidden: !project.isHidden,
                updatedAt: DateTime.now().toUtc()));
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archiwizuj'),
          onPressed: () async {
            await repo.upsert(project.copyWith(
                isArchived: true, updatedAt: DateTime.now().toUtc()));
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
