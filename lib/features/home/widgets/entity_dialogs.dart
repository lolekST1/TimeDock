import 'package:flutter/material.dart';

import '../../../core/upper_case_formatter.dart';
import '../../../domain/services/jira_id_validator.dart';

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

/// Task prompt: name plus optional Jira id. The Jira id, when non-empty, is
/// validated against the format (`PROJ-123`) via the pure domain validator.
Future<TaskInput?> promptForTask(
  BuildContext context, {
  String? initialName,
  String? initialJira,
}) {
  return showDialog<TaskInput>(
    context: context,
    builder: (context) => _TaskDialog(
      initialName: initialName,
      initialJira: initialJira,
    ),
  );
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.initialName, this.initialJira});

  final String? initialName;
  final String? initialJira;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _jiraController =
      TextEditingController(text: widget.initialJira);

  @override
  void dispose() {
    _nameController.dispose();
    _jiraController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final jira = JiraIdValidator.normalize(_jiraController.text);
    Navigator.of(context)
        .pop(TaskInput(name: name, jiraId: jira.isEmpty ? null : jira));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zadanie'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nazwa'),
            ),
            TextFormField(
              controller: _jiraController,
              inputFormatters: const [UpperCaseTextFormatter()],
              decoration:
                  const InputDecoration(labelText: 'Jira ID (opcjonalnie)'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: JiraIdValidator.validate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}
