import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/session_repository.dart';
import '../app_state/app_providers.dart';

/// Lets the user change the running timer's context without restarting it:
/// pick a project, then optionally a sub-project and task. Returns the chosen
/// [SessionContext], or null if dismissed.
Future<SessionContext?> pickContext(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
  String? currentProjectId,
}) {
  return showModalBottomSheet<SessionContext>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ContextPicker(
      workspaceId: workspaceId,
      initialProjectId: currentProjectId,
    ),
  );
}

class _ContextPicker extends ConsumerStatefulWidget {
  const _ContextPicker({required this.workspaceId, this.initialProjectId});

  final String workspaceId;
  final String? initialProjectId;

  @override
  ConsumerState<_ContextPicker> createState() => _ContextPickerState();
}

class _ContextPickerState extends ConsumerState<_ContextPicker> {
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _projectId = widget.initialProjectId;
  }

  @override
  Widget build(BuildContext context) {
    final projects =
        ref.watch(projectsProvider(widget.workspaceId)).valueOrNull ?? const [];

    if (_projectId == null) {
      return _sheet(
        title: 'Wybierz projekt',
        children: [
          for (final p in projects)
            ListTile(
              leading: CircleAvatar(
                  radius: 8, backgroundColor: Color(p.color)),
              title: Text(p.name),
              onTap: () => setState(() => _projectId = p.id),
            ),
        ],
      );
    }

    final subProjects =
        ref.watch(subProjectsProvider(_projectId!)).valueOrNull ?? const [];
    final tasks = ref.watch(tasksProvider(_projectId!)).valueOrNull ?? const [];

    SessionContext ctx({String? subProjectId, String? taskId}) => SessionContext(
          workspaceId: widget.workspaceId,
          projectId: _projectId!,
          subProjectId: subProjectId,
          taskId: taskId,
        );

    return _sheet(
      title: 'Doprecyzuj (opcjonalnie)',
      children: [
        ListTile(
          leading: const Icon(Icons.check),
          title: const Text('Tylko projekt'),
          onTap: () => Navigator.of(context).pop(ctx()),
        ),
        for (final sub in subProjects)
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(sub.name),
            onTap: () => Navigator.of(context).pop(ctx(subProjectId: sub.id)),
          ),
        for (final task in tasks)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(task.name),
            subtitle: task.jiraId == null ? null : Text(task.jiraId!),
            onTap: () => Navigator.of(context).pop(
                ctx(subProjectId: task.subProjectId, taskId: task.id)),
          ),
      ],
    );
  }

  Widget _sheet({required String title, required List<Widget> children}) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...children,
        ],
      ),
    );
  }
}
