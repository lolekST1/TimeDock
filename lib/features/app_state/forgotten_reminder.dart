import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/time_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/services/forgotten_timer.dart';
import '../settings/settings_controller.dart';
import 'app_providers.dart';
import 'context_label.dart';

/// Watchdog that posts the forgotten-timer reminder from the live app process.
///
/// The scheduled system alarm ([ReminderScheduler.scheduleFor]) is unreliable
/// on OEMs that freeze the app and defer the alarm until it is reopened. While
/// a timer runs the foreground service keeps this process alive (and the CPU
/// awake), so a simple periodic check here fires the reminder on time by
/// posting it directly — the mechanism that worked before the service was
/// dropped. The alarm stays as a backup for when the process is killed anyway;
/// both share one notification id, so at most one notification shows.
///
/// Kept alive by being watched in [TimeDockApp]; the timer is bound to the
/// active session's lifetime.
final forgottenReminderWatchdogProvider = Provider<void>((ref) {
  Timer? timer;
  String? remindedSessionId;

  Future<void> check(TimeSession session) async {
    final settings = ref.read(settingsProvider).forgottenTimer;
    if (remindedSessionId == session.id) return;
    if (!ForgottenTimer.shouldRemind(session, DateTime.now().toUtc(), settings)) {
      return;
    }
    remindedSessionId = session.id;
    final label = await ref.read(contextLabelProvider(SessionContext(
      workspaceId: session.workspaceId,
      projectId: session.projectId,
      subProjectId: session.subProjectId,
      taskId: session.taskId,
    )).future);
    await ref.read(reminderSchedulerProvider).showNow(
          session,
          settings,
          contextLabel: label?.path ?? '',
        );
  }

  ref.listen<AsyncValue<TimeSession?>>(activeSessionProvider, (_, next) {
    final session = next.valueOrNull;
    timer?.cancel();
    if (session == null) {
      remindedSessionId = null;
      return;
    }
    // A new session (or a resumed one whose id changed) can remind again.
    if (remindedSessionId != session.id) remindedSessionId = null;
    // Check immediately (covers reopening past the threshold) then every 30s.
    unawaited(check(session));
    timer = Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(check(session)));
  }, fireImmediately: true);

  ref.onDispose(() => timer?.cancel());
});
