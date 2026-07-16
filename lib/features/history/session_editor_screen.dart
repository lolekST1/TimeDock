import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../data/providers.dart';
import '../../data/session_editor.dart';
import '../../domain/entities/time_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/services/jira_id_validator.dart';
import '../app_state/context_label.dart';
import '../timer/context_picker.dart';
import 'history_providers.dart';

/// Edits an existing session or creates a new manual one. Covers the everyday
/// corrections: forgot to start/stop, wrong project, add a remembered session.
class SessionEditorScreen extends ConsumerStatefulWidget {
  const SessionEditorScreen({
    super.key,
    required this.workspaceId,
    this.existing,
    this.initialContext,
    this.initialStartUtc,
    this.initialEndUtc,
  });

  /// Existing session to edit; null for a new manual session.
  final TimeSession? existing;
  final String workspaceId;
  final SessionContext? initialContext;
  final DateTime? initialStartUtc;
  final DateTime? initialEndUtc;

  @override
  ConsumerState<SessionEditorScreen> createState() =>
      _SessionEditorScreenState();
}

class _SessionEditorScreenState extends ConsumerState<SessionEditorScreen> {
  late DateTime _startLocal;
  late DateTime _endLocal;
  late SessionContext _context;
  final _commentController = TextEditingController();
  final _taskController = TextEditingController();
  final _jiraController = TextEditingController();

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      // Use genuine local DateTimes (isUtc == false) so they compare and
      // convert consistently with the values the date/time pickers produce.
      // The startLocal/endLocal getters carry a UTC flag and must not be
      // mixed with picker output.
      _startLocal = existing.startUtc.toLocal();
      _endLocal = existing.endUtc?.toLocal() ??
          existing.startUtc.toLocal().add(const Duration(hours: 1));
      _context = SessionContext(
        workspaceId: existing.workspaceId,
        projectId: existing.projectId,
        subProjectId: existing.subProjectId,
        taskId: existing.taskId,
      );
      _commentController.text = existing.comment ?? '';
      if (existing.taskId != null) _loadTaskFields(existing.taskId!);
    } else {
      _startLocal = (widget.initialStartUtc ?? DateTime.now().toUtc()).toLocal();
      _endLocal = (widget.initialEndUtc ?? DateTime.now().toUtc()).toLocal();
      _context = widget.initialContext ??
          SessionContext(workspaceId: widget.workspaceId, projectId: '');
      if (_context.taskId != null) _loadTaskFields(_context.taskId!);
    }
  }

  Future<void> _loadTaskFields(String taskId) async {
    final task = await ref.read(taskRepositoryProvider).getById(taskId);
    if (!mounted || task == null) return;
    setState(() {
      _taskController.text = task.name;
      _jiraController.text = task.jiraId ?? '';
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _taskController.dispose();
    _jiraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasProject = _context.projectId.isNotEmpty;
    final label = hasProject
        ? ref.watch(contextLabelProvider(_context)).valueOrNull
        : null;
    final duration = _endLocal.difference(_startLocal);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nowa sesja' : 'Edycja sesji'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Usuń',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: label == null
                  ? const Icon(Icons.folder_open)
                  : CircleAvatar(
                      radius: 10, backgroundColor: Color(label.color)),
              title: Text(label?.path ?? 'Wybierz projekt / podprojekt'),
              subtitle: const Text('Dotknij, aby wybrać'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _pickContext,
            ),
          ),
          const SizedBox(height: 8),
          _TimeRow(
            label: 'Początek',
            value: _startLocal,
            onChanged: (v) => setState(() {
              _startLocal = v;
              if (!_endLocal.isAfter(_startLocal)) {
                _endLocal = _startLocal.add(const Duration(minutes: 15));
              }
            }),
          ),
          _TimeRow(
            label: 'Koniec',
            value: _endLocal,
            quickAdjust: true,
            onChanged: (v) => setState(() => _endLocal = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Czas trwania: ${duration.isNegative ? "—" : formatDurationShort(duration)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _taskController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Zadanie',
              hintText: 'np. Landing Page (utworzy się automatycznie)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jiraController,
            decoration: InputDecoration(
              labelText: 'Jira ID',
              hintText: 'np. DAN-1234',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.tag),
              errorText: JiraIdValidator.validate(_jiraController.text),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Komentarz',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Zapisz'),
          ),
          if (!_isNew) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _split,
              icon: const Icon(Icons.call_split),
              label: const Text('Podziel sesję'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickContext() async {
    final picked = await pickContext(
      context,
      ref,
      workspaceId: widget.workspaceId,
      currentProjectId:
          _context.projectId.isEmpty ? null : _context.projectId,
    );
    if (picked == null) return;
    setState(() => _context = picked);
    // Sync the task/Jira fields with the picked context.
    if (picked.taskId != null) {
      await _loadTaskFields(picked.taskId!);
    } else {
      _taskController.clear();
      _jiraController.clear();
    }
  }

  Future<void> _save() async {
    if (_context.projectId.isEmpty) {
      _snack('Wybierz projekt.');
      return;
    }
    if (!_endLocal.isAfter(_startLocal)) {
      _snack('Koniec musi być po początku.');
      return;
    }
    if (!JiraIdValidator.isValid(_jiraController.text)) {
      _snack('Nieprawidłowy format Jira ID (np. ABS-123).');
      return;
    }

    // Resolve the ad-hoc task/Jira: find-or-create under the current context.
    final taskId = await ref.read(taskQuickAddProvider).findOrCreate(
          projectId: _context.projectId,
          subProjectId: _context.subProjectId,
          name: _taskController.text,
          jiraId: _jiraController.text,
        );

    final editor = ref.read(sessionEditorProvider);
    final comment = _commentController.text.trim().isEmpty
        ? null
        : _commentController.text.trim();
    final now = DateTime.now().toUtc();

    final TimeSession candidate;
    if (_isNew) {
      candidate = editor
          .buildManual(
            context: _context,
            startUtc: _startLocal.toUtc(),
            endUtc: _endLocal.toUtc(),
            startOffsetMinutes: _startLocal.timeZoneOffset.inMinutes,
            endOffsetMinutes: _endLocal.timeZoneOffset.inMinutes,
            comment: comment,
            nowUtc: now,
          )
          .copyWith(taskId: taskId);
    } else {
      candidate = widget.existing!.copyWith(
        projectId: _context.projectId,
        subProjectId: _context.subProjectId,
        taskId: taskId,
        startUtc: _startLocal.toUtc(),
        endUtc: _endLocal.toUtc(),
        startOffsetMinutes: _startLocal.timeZoneOffset.inMinutes,
        endOffsetMinutes: _endLocal.timeZoneOffset.inMinutes,
        comment: comment,
        wasEdited: true,
        updatedAt: now,
      );
    }

    final result = await editor.save(candidate);
    if (!mounted) return;
    switch (result) {
      case EditSaved():
        Navigator.of(context).pop();
      case EditInvalid(:final reason):
        _snack(reason);
      case EditConflict():
        final proceed = await _confirmConflict();
        if (proceed == true) {
          await ref.read(sessionRepositoryProvider).upsert(candidate);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }

  Future<bool?> _confirmConflict() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nakładające się sesje'),
        content: const Text(
          'Ta sesja nachodzi na inną, której nie można automatycznie '
          'przyciąć. Zapisać mimo to?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zapisz mimo to'),
          ),
        ],
      ),
    );
  }

  Future<void> _split() async {
    final existing = widget.existing!;
    if (existing.endUtc == null) return;
    final startLocal = existing.startUtc.toLocal();
    final endLocal = existing.endUtc!.toLocal();
    final mid = startLocal.add(endLocal.difference(startLocal) ~/ 2);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(mid),
      helpText: 'Punkt podziału',
    );
    if (picked == null) return;
    final splitLocal = DateTime(startLocal.year, startLocal.month,
        startLocal.day, picked.hour, picked.minute);
    final splitUtc = splitLocal.toUtc();
    if (!splitUtc.isAfter(existing.startUtc) ||
        !splitUtc.isBefore(existing.endUtc!)) {
      _snack('Punkt podziału musi być wewnątrz sesji.');
      return;
    }
    await ref.read(sessionEditorProvider).split(
          existing,
          atUtc: splitUtc,
          atOffsetMinutes: splitLocal.timeZoneOffset.inMinutes,
          nowUtc: DateTime.now().toUtc(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    await ref.read(sessionEditorProvider).delete(existing.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Sesja usunięta'),
        action: SnackBarAction(
          label: 'Cofnij',
          onPressed: () =>
              ref.read(sessionRepositoryProvider).upsert(existing),
        ),
      ));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.quickAdjust = false,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool quickAdjust;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + date + time. Wrap prevents overflow on narrow screens.
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      onPressed: () => _pickDate(context),
                      label: Text(formatIsoDate(value)),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      onPressed: () => _pickTime(context),
                      label: Text(formatTimeOfDay(value)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (quickAdjust)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 72),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _AdjustChip(
                      label: '−15 min',
                      onTap: () => onChanged(
                          value.subtract(const Duration(minutes: 15)))),
                  _AdjustChip(
                      label: '+15 min',
                      onTap: () =>
                          onChanged(value.add(const Duration(minutes: 15)))),
                  _AdjustChip(
                      label: '+30 min',
                      onTap: () =>
                          onChanged(value.add(const Duration(minutes: 30)))),
                  _AdjustChip(
                      label: '+1 h',
                      onTap: () =>
                          onChanged(value.add(const Duration(hours: 1)))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day, value.hour,
          value.minute));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (picked != null) {
      onChanged(DateTime(
          value.year, value.month, value.day, picked.hour, picked.minute));
    }
  }
}

class _AdjustChip extends StatelessWidget {
  const _AdjustChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
