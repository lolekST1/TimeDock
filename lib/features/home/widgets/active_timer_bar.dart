import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ticker.dart';
import '../../../core/ui/td_tokens.dart';
import '../../../domain/entities/time_session.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../app_state/app_providers.dart';
import '../../app_state/context_label.dart';
import '../../timer/active_timer_screen.dart';

/// Persistent bar shown above the bottom nav while a timer runs. It takes the
/// project's colour so the running timer is instantly recognisable; tapping it
/// opens the full active-timer screen and STOP ends the session.
class ActiveTimerBar extends ConsumerWidget {
  const ActiveTimerBar({super.key, required this.session});

  final TimeSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref
        .watch(contextLabelProvider(SessionContext(
          workspaceId: session.workspaceId,
          projectId: session.projectId,
          subProjectId: session.subProjectId,
          taskId: session.taskId,
        )))
        .valueOrNull;

    final base = label != null ? Color(label.color) : context.cs.primary;
    // A subtle vertical gradient from the project colour deepens the bar.
    final deep = Color.lerp(base, const Color(0xFF0B1220), 0.42)!;
    final onBar = ThemeData.estimateBrightnessForColor(base) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final onBarSoft = onBar.withValues(alpha: 0.82);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, deep],
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ActiveTimerScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  color: onBar, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'TRWA POMIAR',
                              style: TextStyle(
                                color: onBarSoft,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        TimerCounter(
                          startUtc: session.startUtc,
                          style: TextStyle(
                            color: onBar,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          label?.path ?? '…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: onBarSoft, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StopButton(onBar: onBar, onStop: () {
                    unawaited(HapticFeedback.mediumImpact());
                    ref.read(timerServiceProvider).stop();
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onBar, required this.onStop});

  final Color onBar;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onBar.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: onBar.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStop,
        child: SizedBox(
          width: 60,
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: onBar,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'STOP',
                style: TextStyle(
                  color: onBar,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
