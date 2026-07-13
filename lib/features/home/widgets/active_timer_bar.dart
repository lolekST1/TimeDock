import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ticker.dart';
import '../../../domain/entities/time_session.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../app_state/app_providers.dart';
import '../../app_state/context_label.dart';
import '../../timer/active_timer_screen.dart';

/// Persistent bar shown at the bottom of the home screen while a timer runs.
/// Tapping it opens the full active-timer screen; STOP ends the session.
class ActiveTimerBar extends ConsumerWidget {
  const ActiveTimerBar({super.key, required this.session});

  final TimeSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final label = ref
        .watch(contextLabelProvider(SessionContext(
          workspaceId: session.workspaceId,
          projectId: session.projectId,
          subProjectId: session.subProjectId,
          taskId: session.taskId,
        )))
        .valueOrNull;

    return Material(
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ActiveTimerScreen(),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TimerCounter(
                        startUtc: session.startUtc,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                      ),
                      Text(
                        label?.path ?? '…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    unawaited(HapticFeedback.mediumImpact());
                    ref.read(timerServiceProvider).stop();
                  },
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('STOP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
