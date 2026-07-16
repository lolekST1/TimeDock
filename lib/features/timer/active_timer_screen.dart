import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ticker.dart';
import '../../core/time_format.dart';
import '../../data/providers.dart';
import '../../domain/entities/time_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/services/forgotten_timer.dart';
import '../../domain/services/jira_id_validator.dart';
import '../app_state/app_providers.dart';
import '../app_state/context_label.dart';
import '../history/history_providers.dart';
import '../settings/settings_controller.dart';
import 'context_picker.dart';

/// The active-timer screen. The counter dominates; the context, comment and
/// Jira id can be filled in now or later. Editing here never restarts the
/// clock.
class ActiveTimerScreen extends ConsumerStatefulWidget {
  const ActiveTimerScreen({super.key});

  @override
  ConsumerState<ActiveTimerScreen> createState() => _ActiveTimerScreenState();
}

class _ActiveTimerScreenState extends ConsumerState<ActiveTimerScreen> {
  final _commentController = TextEditingController();
  final _taskController = TextEditingController();
  final _jiraController = TextEditingController();
  String? _loadedForSessionId;

  @override
  void dispose() {
    _commentController.dispose();
    _taskController.dispose();
    _jiraController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskFields(String? taskId) async {
    if (taskId == null) {
      _taskController.clear();
      _jiraController.clear();
      return;
    }
    final task = await ref.read(taskRepositoryProvider).getById(taskId);
    if (!mounted || task == null) return;
    setState(() {
      _taskController.text = task.name;
      _jiraController.text = task.jiraId ?? '';
    });
  }

  Future<void> _saveComment(TimeSession session) async {
    final text = _commentController.text.trim();
    final value = text.isEmpty ? null : text;
    if (value == session.comment) return;
    await ref.read(sessionRepositoryProvider).upsert(
          session.copyWith(comment: value, updatedAt: DateTime.now().toUtc()),
        );
  }

  /// Find-or-create the typed task/Jira and attach it to the running session
  /// without restarting the clock. No-op when both fields are empty and there
  /// was no task before.
  Future<void> _saveTask(TimeSession session) async {
    // Don't persist a malformed Jira id; the field shows the validation error.
    if (!JiraIdValidator.isValid(_jiraController.text)) return;
    final taskId = await ref.read(taskQuickAddProvider).findOrCreate(
          projectId: session.projectId,
          subProjectId: session.subProjectId,
          name: _taskController.text,
          jiraId: _jiraController.text,
        );
    if (taskId == null && session.taskId == null) return;
    if (taskId == session.taskId) return;
    await ref.read(timerServiceProvider).switchContext(SessionContext(
          workspaceId: session.workspaceId,
          projectId: session.projectId,
          subProjectId: session.subProjectId,
          taskId: taskId,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider).valueOrNull;

    if (session == null) {
      // Timer stopped elsewhere: leave the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    // Load the comment and task fields into the form once per session.
    if (_loadedForSessionId != session.id) {
      _loadedForSessionId = session.id;
      _commentController.text = session.comment ?? '';
      _loadTaskFields(session.taskId);
    }

    final label = ref
        .watch(contextLabelProvider(SessionContext(
          workspaceId: session.workspaceId,
          projectId: session.projectId,
          subProjectId: session.subProjectId,
          taskId: session.taskId,
        )))
        .valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final projectColor = label != null ? Color(label.color) : null;
    final onProject = projectColor != null &&
            ThemeData.estimateBrightnessForColor(projectColor) ==
                Brightness.dark
        ? Colors.white
        : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktywny timer'),
        backgroundColor: projectColor,
        foregroundColor: projectColor != null ? onProject : null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                children: [
                  Center(
                    child: TimerCounter(
                      startUtc: session.startUtc,
                      style:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                fontWeight: FontWeight.w300,
                              ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: label == null
                          ? const Icon(Icons.folder_open)
                          : CircleAvatar(
                              radius: 10,
                              backgroundColor: Color(label.color)),
                      title: Text(label?.path ?? '…'),
                      subtitle: const Text('Dotknij, aby zmienić projekt'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _changeContext(session),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taskController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Zadanie',
                      hintText: 'np. Landing Page (utworzy się automatycznie)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                    onEditingComplete: () {
                      _saveTask(session);
                      FocusScope.of(context).unfocus();
                    },
                    onTapOutside: (_) => _saveTask(session),
                  ),
                  const SizedBox(height: 12),
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
                    onEditingComplete: () {
                      _saveTask(session);
                      FocusScope.of(context).unfocus();
                    },
                    onTapOutside: (_) => _saveTask(session),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Komentarz',
                      hintText: 'Co konkretnie robisz w tej sesji?',
                      border: OutlineInputBorder(),
                    ),
                    onEditingComplete: () {
                      _saveComment(session);
                      FocusScope.of(context).unfocus();
                    },
                    onTapOutside: (_) => _saveComment(session),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: SizedBox(
                height: 64,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                  ),
                  onPressed: () => _stop(session),
                  icon: const Icon(Icons.stop_rounded, size: 28),
                  label: const Text('STOP', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeContext(TimeSession session) async {
    final picked = await pickContext(
      context,
      ref,
      workspaceId: session.workspaceId,
      currentProjectId: session.projectId,
    );
    if (picked != null) {
      await ref.read(timerServiceProvider).switchContext(picked);
    }
  }

  Future<void> _stop(TimeSession initial) async {
    await _saveComment(initial);
    await _saveTask(initial);
    // Re-read after the comment/task writes so the trim below doesn't revert
    // them.
    final session = await ref.read(sessionRepositoryProvider).getActive();
    if (session == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final now = DateTime.now().toUtc();
    final settings = ref.read(settingsProvider).forgottenTimer;

    if (ForgottenTimer.shouldSuggestTrimOnStop(session, now, settings)) {
      final trimTo = await _askTrim(session, now, settings);
      if (trimTo == null) return; // cancelled
      if (trimTo != now) {
        // Save with the user-chosen (trimmed) end.
        await ref.read(sessionRepositoryProvider).upsert(session.copyWith(
              endUtc: trimTo,
              endOffsetMinutes: trimTo.toLocal().timeZoneOffset.inMinutes,
              wasEdited: true,
              updatedAt: now,
            ));
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    await ref.read(timerServiceProvider).stop();
    if (mounted) Navigator.of(context).pop();
  }

  /// Returns the chosen end instant, or null if the user cancelled.
  /// Returning [now] means "keep the full duration".
  Future<DateTime?> _askTrim(
    TimeSession session,
    DateTime now,
    ForgottenTimerSettings settings,
  ) {
    final suggested =
        ForgottenTimer.suggestedTrimEndUtc(session, now, settings);
    final elapsed = session.durationAt(now);
    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Długa sesja'),
        content: Text(
          'Ta sesja trwa ${formatDurationShort(elapsed)}. '
          'Czy timer został przypadkiem zostawiony włączony?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(now),
            child: const Text('Zachowaj całość'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(suggested),
            child: Text('Przytnij do ${formatTimeOfDay(
              suggested.add(Duration(minutes: session.startOffsetMinutes)),
            )}'),
          ),
        ],
      ),
    );
  }
}
