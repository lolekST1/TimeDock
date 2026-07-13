import 'package:flutter/material.dart';

/// Simple name prompt used for projects and sub-projects.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nazwa'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            Navigator.of(context).pop(v.isEmpty ? null : v);
          },
          child: const Text('Zapisz'),
        ),
      ],
    ),
  );
}

class TaskInput {
  const TaskInput({required this.name, this.jiraId});
  final String name;
  final String? jiraId;
}

/// Task prompt: name plus optional Jira id.
Future<TaskInput?> promptForTask(
  BuildContext context, {
  String? initialName,
  String? initialJira,
}) {
  final nameController = TextEditingController(text: initialName);
  final jiraController = TextEditingController(text: initialJira);
  return showDialog<TaskInput>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Zadanie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nazwa'),
          ),
          TextField(
            controller: jiraController,
            decoration: const InputDecoration(labelText: 'Jira ID (opcjonalnie)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              Navigator.of(context).pop();
              return;
            }
            final jira = jiraController.text.trim();
            Navigator.of(context)
                .pop(TaskInput(name: name, jiraId: jira.isEmpty ? null : jira));
          },
          child: const Text('Zapisz'),
        ),
      ],
    ),
  );
}
