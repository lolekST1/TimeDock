import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'domain/entities/time_session.dart';
import 'domain/repositories/session_repository.dart';
import 'features/app_state/app_providers.dart';
import 'features/app_state/context_label.dart';
import 'features/app_state/forgotten_reminder.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_controller.dart';
import 'main.dart' show applyPendingStop;

class TimeDockApp extends ConsumerStatefulWidget {
  const TimeDockApp({super.key});

  @override
  ConsumerState<TimeDockApp> createState() => _TimeDockAppState();
}

class _TimeDockAppState extends ConsumerState<TimeDockApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If STOP was pressed on the notification while the app was frozen, close
    // the session at the recorded instant as soon as we come back; then
    // re-post the notification for a still-running session (the user may have
    // swiped it away — plain ongoing notifications are dismissable on 14+).
    if (state == AppLifecycleState.resumed) {
      final container = ProviderScope.containerOf(context, listen: false);
      applyPendingStop(container).then((_) => _resyncNotification());
    }
  }

  Future<void> _resyncNotification() async {
    final session = ref.read(activeSessionProvider).valueOrNull;
    if (session == null) return;
    final label = await ref.read(contextLabelProvider(SessionContext(
      workspaceId: session.workspaceId,
      projectId: session.projectId,
      subProjectId: session.subProjectId,
      taskId: session.taskId,
    )).future);
    final current = ref.read(activeSessionProvider).valueOrNull;
    if (current?.id == session.id) {
      await ref
          .read(timerForegroundServiceProvider)
          .show(session, label?.path ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Post the forgotten-timer reminder from the live process (backed by the
    // foreground service keeping it alive), not just the deferred alarm.
    ref.watch(forgottenReminderWatchdogProvider);

    // Mirror the running timer into the notification and the scheduled
    // forgotten-timer reminder (a system alarm, so it fires in Doze).
    ref.listen<AsyncValue<TimeSession?>>(activeSessionProvider,
        (previous, next) {
      final service = ref.read(timerForegroundServiceProvider);
      final scheduler = ref.read(reminderSchedulerProvider);
      final session = next.valueOrNull;
      if (session == null) {
        service.hide();
        scheduler.cancel();
        return;
      }
      final sessionContext = SessionContext(
        workspaceId: session.workspaceId,
        projectId: session.projectId,
        subProjectId: session.subProjectId,
        taskId: session.taskId,
      );
      // Await the resolved label so the notification shows the project name
      // rather than the fallback title (the label future may not be ready yet
      // at start). Guard against a stale label overwriting a newer context.
      ref.read(contextLabelProvider(sessionContext).future).then((label) {
        final current = ref.read(activeSessionProvider).valueOrNull;
        if (current == null) return;
        final stillCurrent = current.id == session.id &&
            current.projectId == session.projectId &&
            current.subProjectId == session.subProjectId &&
            current.taskId == session.taskId;
        if (stillCurrent) {
          final path = label?.path ?? '';
          service.show(session, path);
          scheduler.scheduleFor(
            session,
            ref.read(settingsProvider).forgottenTimer,
            contextLabel: path,
          );
        }
      });
    });

    // Theme follows the selected workspace's seed color.
    final workspaces = ref.watch(workspacesProvider).valueOrNull;
    final selectedId = ref.watch(selectedWorkspaceProvider);
    final seed = workspaces
            ?.where((w) => w.id == selectedId)
            .firstOrNull
            ?.colorSeed ??
        0xFF1565C0;

    final themeMode = ref.watch(settingsProvider).themeMode;

    return MaterialApp(
      title: 'TimeDock',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: timeDockTheme(seed, Brightness.light),
      darkTheme: timeDockTheme(seed, Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
