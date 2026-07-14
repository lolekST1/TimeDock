import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'domain/entities/time_session.dart';
import 'domain/repositories/session_repository.dart';
import 'features/app_state/app_providers.dart';
import 'features/app_state/context_label.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_controller.dart';

class TimeDockApp extends ConsumerWidget {
  const TimeDockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mirror the running timer into the foreground-service notification.
    ref.listen<AsyncValue<TimeSession?>>(activeSessionProvider,
        (previous, next) {
      final service = ref.read(timerForegroundServiceProvider);
      final session = next.valueOrNull;
      if (session == null) {
        service.hide();
        return;
      }
      final label = ref
          .read(contextLabelProvider(SessionContext(
            workspaceId: session.workspaceId,
            projectId: session.projectId,
            subProjectId: session.subProjectId,
            taskId: session.taskId,
          )))
          .valueOrNull;
      service.show(session, label?.path ?? '');
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
      // Enables the ongoing-timer notification's tap-to-open and the STOP
      // button bridge to work while this screen is mounted.
      home: const WithForegroundTask(child: HomeScreen()),
    );
  }
}
