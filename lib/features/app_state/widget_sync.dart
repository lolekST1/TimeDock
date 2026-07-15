import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/session_repository.dart';
import 'app_providers.dart';
import 'context_label.dart';

/// Keeps the home-screen widget's recent-context tiles in sync with the app.
///
/// Sends the selected workspace's most recent contexts (resolved to a display
/// title, colour, and the ids needed to start them) to the native side, which
/// stores them and re-renders. Kept alive by being watched in [TimeDockApp].
final widgetSyncProvider = Provider<void>((ref) {
  final workspaceId = ref.watch(selectedWorkspaceProvider);
  if (workspaceId == null) return;

  Future<void> sync() async {
    final contexts = ref.read(recentContextsProvider(workspaceId)).valueOrNull;
    if (contexts == null) return;
    final payload = <Map<String, dynamic>>[];
    for (final c in contexts.take(3)) {
      final label = await ref.read(contextLabelProvider(c).future);
      if (label == null) continue;
      payload.add(<String, dynamic>{
        'title': label.path,
        'color': label.color,
        'workspaceId': c.workspaceId,
        'projectId': c.projectId,
        'subProjectId': c.subProjectId,
        'taskId': c.taskId,
      });
    }
    await ref
        .read(timerForegroundServiceProvider)
        .updateWidget(jsonEncode(payload));
  }

  ref.listen<AsyncValue<List<SessionContext>>>(
    recentContextsProvider(workspaceId),
    (_, __) => unawaited(sync()),
    fireImmediately: true,
  );
});
