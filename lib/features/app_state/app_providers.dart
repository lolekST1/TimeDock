import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';
import '../../data/services/reminder_scheduler.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/sub_project.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/time_session.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/services/timer_foreground_service.dart';
import '../../domain/services/timer_service.dart';

/// Bound in [main] once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
    (ref) => throw StateError('sharedPreferencesProvider not overridden'));

final timerServiceProvider = Provider<TimerService>(
    (ref) => TimerService(ref.watch(sessionRepositoryProvider)));

/// The always-on timer notification / foreground service. Defaults to a no-op;
/// the Android implementation is overridden in [main] on that platform. The
/// timer works regardless of whether the service is alive.
final timerForegroundServiceProvider = Provider<TimerForegroundService>(
    (ref) => const NoopTimerForegroundService());

/// Forgotten-timer reminder scheduling (system alarm). No-op by default;
/// Android override in [main].
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => const NoopReminderScheduler());

/// The single running session across the whole app, or null. Sourced from the
/// database so it is correct after a restart.
final activeSessionProvider = StreamProvider<TimeSession?>(
    (ref) => ref.watch(sessionRepositoryProvider).watchActive());

final workspacesProvider = StreamProvider<List<Workspace>>(
    (ref) => ref.watch(workspaceRepositoryProvider).watchAll());

const _selectedWorkspaceKey = 'selected_workspace_id';

/// Remembers the last selected workspace across launches. Falls back to the
/// first available workspace until the user picks one.
class SelectedWorkspaceNotifier extends Notifier<String?> {
  @override
  String? build() {
    final stored =
        ref.watch(sharedPreferencesProvider).getString(_selectedWorkspaceKey);
    if (stored != null) return stored;
    // Default to the first workspace once the list has loaded.
    final workspaces = ref.watch(workspacesProvider).valueOrNull;
    if (workspaces != null && workspaces.isNotEmpty) {
      return workspaces.first.id;
    }
    return null;
  }

  Future<void> select(String workspaceId) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_selectedWorkspaceKey, workspaceId);
    state = workspaceId;
  }
}

final selectedWorkspaceProvider =
    NotifierProvider<SelectedWorkspaceNotifier, String?>(
        SelectedWorkspaceNotifier.new);

final projectsProvider =
    StreamProvider.family<List<Project>, String>((ref, workspaceId) {
  return ref.watch(projectRepositoryProvider).watchByWorkspace(workspaceId);
});

final subProjectsProvider =
    StreamProvider.family<List<SubProject>, String>((ref, projectId) {
  return ref.watch(subProjectRepositoryProvider).watchByProject(projectId);
});

/// Sub-projects including archived ones, for management screens.
final allSubProjectsProvider =
    StreamProvider.family<List<SubProject>, String>((ref, projectId) {
  return ref
      .watch(subProjectRepositoryProvider)
      .watchByProject(projectId, includeArchived: true);
});

/// Archived projects in a workspace, for the restore/archive screen.
final archivedProjectsProvider =
    StreamProvider.family<List<Project>, String>((ref, workspaceId) {
  return ref
      .watch(projectRepositoryProvider)
      .watchByWorkspace(workspaceId, includeHidden: true, includeArchived: true)
      .map((projects) =>
          projects.where((p) => p.isArchived).toList(growable: false));
});

final tasksProvider =
    StreamProvider.family<List<Task>, String>((ref, projectId) {
  return ref.watch(taskRepositoryProvider).watchByProject(projectId);
});

final recentContextsProvider =
    StreamProvider.family<List<SessionContext>, String>((ref, workspaceId) {
  return ref
      .watch(sessionRepositoryProvider)
      .watchRecentContexts(workspaceId);
});
