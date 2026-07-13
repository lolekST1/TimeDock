import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../data/providers.dart';
import '../../data/session_editor.dart';
import '../../domain/entities/time_session.dart';
import '../../domain/repositories/session_repository.dart';
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

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _startLocal = existing.startLocal;
      _endLocal = existing.endLocal ?? existing.startLocal.add(const Duration(hours: 1));
      _context = SessionContext(
        workspaceId: existing.workspaceId,
        projectId: existing.projectId,
        subProjectId: existing.subProjectId,
        taskId: existing.taskId,
      );
      _commentController.text = existing.comment ?? '';
    } else {
      _startLocal = (widget.initialStartUtc ?? DateTime.now().toUtc())
          .toLocal();
      _endLocal = (widget.initialEndUtc ?? DateTime.now().toUtc()).toLocal();
      _context = widget.initialContext ??
          SessionContext(workspaceId: widget.workspaceId, projectId: '');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
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
              title: Text(label?.path ?? 'Wybierz projekt'),
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
            onChanged: (v) => setState(() => _endLocal = v),
            quickAdjust: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Czas trwania: ${duration.isNegative ? "—" : formatDurationShort(duration)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
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
    if (picked != null) setState(() => _context = picked);
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
    final editor = ref.read(sessionEditorProvider);
    final comment =
        _commentController.text.trim().isEmpty ? null : _commentController.text.trim();
    final now = DateTime.now().toUtc();

    final TimeSession candidate;
    if (_isNew) {
      candidate = editor.buildManual(
        context: _context,
        startUtc: _startLocal.toUtc(),
        endUtc: _endLocal.toUtc(),
        startOffsetMinutes: _startLocal.timeZoneOffset.inMinutes,
        endOffsetMinutes: _endLocal.timeZoneOffset.inMinutes,
        comment: comment,
        nowUtc: now,
      );
    } else {
      candidate = widget.existing!.copyWith(
        projectId: _context.projectId,
        subProjectId: _context.subProjectId,
        taskId: _context.taskId,
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
          // Apply candidate over the unresolvable neighbour by forcing save of
          // just the candidate (kept simple: overwrite, user chose to proceed).
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
    final end = existing.endLocal ?? _endLocal;
    final mid = existing.startLocal.add(
        end.difference(existing.startLocal) ~/ 2);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(mid),
      helpText: 'Punkt podziału',
    );
    if (picked == null) return;
    final splitLocal = DateTime(existing.startLocal.year,
        existing.startLocal.month, existing.startLocal.day, picked.hour, picked.minute);
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label)),
          OutlinedButton(
            onPressed: () => _pickDate(context),
            child: Text(
                '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _pickTime(context),
            child: Text(formatTimeOfDay(value)),
          ),
          if (quickAdjust) ...[
            const Spacer(),
            IconButton(
              tooltip: '-15 min',
              icon: const Icon(Icons.remove),
              onPressed: () =>
                  onChanged(value.subtract(const Duration(minutes: 15))),
            ),
            IconButton(
              tooltip: '+15 min',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  onChanged(value.add(const Duration(minutes: 15))),
            ),
          ],
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
