import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ticker.dart';
import '../../domain/repositories/session_repository.dart';
import '../app_state/app_providers.dart';
import '../app_state/context_label.dart';

/// The active-timer screen. The counter dominates; everything else can be
/// filled in later. Editing the context and comment lands here in stage 3.
class ActiveTimerScreen extends ConsumerWidget {
  const ActiveTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).valueOrNull;

    // Timer stopped (e.g. from elsewhere): leave the screen.
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: SizedBox.shrink());
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

    return Scaffold(
      appBar: AppBar(title: const Text('Aktywny timer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: TimerCounter(
                startUtc: session.startUtc,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w300,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                label?.path ?? '…',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                ),
                onPressed: () async {
                  await ref.read(timerServiceProvider).stop();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.stop_rounded, size: 28),
                label: const Text('STOP', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
